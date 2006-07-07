package SWISH::Prog::DBI;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use DBI;
use Search::Tools::XML;
use SWISH::Prog::DBI::Doc;

use base qw( SWISH::Prog );

our $VERSION = '0.01';
our $Debug   = $ENV{PERL_DEBUG} || 0;
our $XMLer   = Search::Tools::XML->new;

=pod

=head1 NAME

SWISH::Prog::DBI - index DB records with Swish-e

=head1 SYNOPSIS

    package My::DBI::Prog;
    use base qw( SWISH::Prog::DBI );
    
    1;
    
    package My::DBI::Prog::Doc;
    use base qw( SWISH::Prog::DBI::Doc );
    
    sub url_filter
    {
        my $doc = shift;
        my $db_data = $doc->row;
        $doc->url( $db_data->{colname_I_want_as_url} );
    }
    
    1;
    
    package main;
    use Carp;
    
    my $dbi_indexer = My::DBI::Prog->new(
        db => [
            "DBI:mysql:database=movies;host=localhost;port=3306",
            'some_user', 'some_secret_pass',
            {
                RaiseError  => 1,
                HandleError => sub { confess(shift) },
            }
        ]
    );
    
    $dbi_indexer->create(
            tables => {
                'moviesIlike' => {
                    title       => 1,
                    synopsis    => 1,
                    year        => 1,
                    director    => 1,
                    producer    => 1,
                    awards      => 1
                    }
                 }
                );


=head1 DESCRIPTION

SWISH::Prog::DBI is a SWISH::Prog subclass designed for providing full-text
search for your databases with Swish-e.

Since SWISH::Prog::DBI inherits from SWISH::Prog, read the SWISH::Prog docs
first. Any overridden methods are documented here.

=head1 VARIABLES

=over

=item Debug

Default is 0. Set to 1 (true) for verbage on stderr.

=back

=head1 METHODS

=cut

=pod

=head2 new( db => I<DBI_connect_info> )

Create new indexer object. I<DBI_connect_info> is passed
directly to DBI's connect() method, so see the DBI docs for syntax.
If I<DBI_connect_info> is a DBI handle object, it is accepted as is.
If I<DBI_connect_info> is an array ref, it will be dereferenced and
passed to connect(). Otherwise it will be passed to connect as is.

B<NOTE:> The new() method simply inherits from SWISH::Prog, so any params
valid for that method() are allowed here.

=head2 init

Initialize object. This overrides SWISH::Prog init() base method.

=cut

sub init
{
    my $self = shift;

    $self->mk_accessors(qw/ meta db quiet title /);

    # verify DBI connection
    if (ref $self->db && ref $self->db eq 'ARRAY')
    {
        $self->db(DBI->connect(@{$self->{db}}));
    }
    elsif (ref $self->db && $self->db->isa('DBI'))
    {

        # do nothing

    }
    elsif ($self->db)
    {
        $self->db(DBI->connect($self->db));
    }
    else
    {
        croak "need DBI connection info";
    }

    $self->{debug} ||= $Debug || 0;

    # cache meta
    $self->info;

}

=pod

=head2 init_indexer

Adds the special C<table> MetaName to the Config object before
opening indexer.

=cut

sub init_indexer
{
    my $self = shift;

    # add 'table' metaname
    $self->config->metanames('table');

    # save all row text in the swishdescription property for excerpts
    $self->config->StoreDescription('XML* <_desc>');

    # TODO get version
    $self->config->write2;

    $self->indexer(SWISH::Prog::Index->new($self)->run);
    $self->fh($self->indexer->fh);

}

=pod

=head2 DESTROY

Calls the DBI disconnect() method on the cached dbh before
calling the SWISH::Prog::DESTROY method.

B<NOTE:> Internal method only.

=cut

sub DESTROY
{
    my $self = shift;
    $self->db->disconnect
      or croak "can't close db connection " . $self->db->{Name} . ": $!\n";

    # pass on to base class
    $self->SUPER::DESTROY();    # funny name...
}

# basic flow:
# get db meta: table names and column names
# foreach table, create index
# select * from table
# while row, convert row to xml, create Doc object and call index()

=pod

=head2 info

Internal method for retrieving db meta data.

=cut

sub info
{
    my $self = shift;

    my $sth = $self->db->prepare(" show tables ");
    $sth->execute or croak $sth->errstr;

    my %meta;
    for my $t (@{$sth->fetchall_arrayref})
    {
        my %table = (
                     name => $t->[0],
                     cols => $self->cols($t->[0])
                    );
        $meta{$t->[0]} = \%table;
    }

    $self->meta(\%meta);
}

=pod

=head2 cols

Internal method for retrieving db column data.

=cut

sub cols
{
    my $self = shift;
    my $name = shift or croak "need table name";

    my $sth = $self->{db}->column_info(undef, undef, $name, '%');

    my %cols;
    for my $colname (keys %{$sth->fetchall_hashref('COLUMN_NAME')})
    {

        # TODO determine type for setting Swish Property type
        # for now we treat all as char type

        $cols{$colname} = {type => 1};

    }

    return \%cols;
}

=pod

=head2 meta

Get all the table/column info for the current db.

=cut

=pod

=head2 create( I<opts> )

Create index. The default is for all tables to be indexed,
with each table name saved in the C<tablename> MetaName.

I<opts> supports the following options:

=over

=item tables

Only index the following tables (and optionally, columns within tables).

Example:

If you only want to index the table C<foo> and only the columns C<bar>
and C<gab>, pass this:

 $dbi->index( tables => { foo => { columns => bar=>1, gab=>1 } } } );

To index all columns:

 $dbi->index( tables => { foo => 1 } );

=item TODO

=back

 #TODO - make the column hash value the MetaRankBias for that column

B<NOTE:> index() calls index_sql() internally to actually create each
index. If you want to tailor your SQL (using JOINs etc.) then you probably
want to call index_sql() directly for each index you want created.

=cut

sub create
{
    my $self = shift;
    my %opts = @_;

    my @tables;

    if (exists $opts{tables})
    {
        @tables = sort keys %{$opts{tables}};
    }
    else
    {
        @tables = sort keys %{$self->meta};
    }

  T: for my $table (@tables)
    {

        # which columns to index
        my @cols;
        if (exists $opts{tables}->{$table} && ref $opts{tables}->{$table})
        {
            @cols = sort keys %{$opts{tables}->{$table}->{columns}};
        }
        else
        {
            @cols = sort keys %{$self->meta->{$table}->{cols}};
        }

        $self->index_sql(
                       name => $table . ".index",
                       sql => "SELECT `" . join('`,`', @cols) . "` FROM $table",
                       table => $table,
                       desc  => $opts{tables}->{$table}->{desc} || {},
                       title => $opts{tables}->{$table}->{title} || ''
        );

    }

}

=pod

=head2 index_sql( %opts )

Fetch rows from the DB, convert to XML and pass to inherited index()
method. %opts should include at least the following:

=over

=item sql

The SQL statement to execute.

=back

%opts may also contain:

=over

=item table

The name of the table. Used for creating virtual XML documents passed
to indexer.

=item title

Which column to use as the title of the virtual document. If not
defined, the title will be the empty string.

=back

%opts may contain any other param that SWISH::Prog::Index->new() accepts.

Example:

 $prog_dbi->index_sql(  sql => 'SELECT * FROM `movies`',
                        title => 'Movie_Title'
                        );
                        
=cut

sub index_sql
{
    my $self = shift;
    my %opts = @_;

    if (!$opts{sql})
    {
        croak "need SQL statement to index with";
    }

    $opts{table} ||= '';

    my $counter = 0;

    my $sth = $self->db->prepare($opts{sql});
    $sth->execute or croak "SELECT failed " . $sth->errstr;

    $self->quiet or print STDOUT "Indexing $opts{table} ...                   ";

    while (my $row = $sth->fetchrow_hashref)
    {

        $self->row_filter($row);

        my $title =
          exists $row->{$opts{title}}
          ? $row->{$opts{title}}
          : $self->title_filter($row);

        my $xml =
          $self->row2xml($XMLer->tag_safe($opts{table}),
                         $row, $title, \%opts);

        my $doc =
          $self->docclass->new(
                               content => $xml,
                               url     => ++$counter,
                               modtime => time(),
                               parser  => 'XML*',
                               type    => 'application/dbi',
                               row     => $row
                              );

        $self->index($doc);

        $self->quiet
          or print STDOUT "\b" x (length($counter) + 6), $counter, "  rows";

    }

    $self->quiet
      or print STDOUT "\b" x (length($counter) + 6), "  done        \n";

}

=head2 row2xml( I<table_name>, I<row_hash_ref>, I<title> )

Converts I<row_hash_ref> to a XML string. Returns the XML.

The I<table_name> is included in C<<table>> tagset within
each row. You can use the C<table> MetaName to limit
searches to a specific table.

=cut

sub row2xml
{
    my $self  = shift;
    my $table = shift;
    my $row   = shift;
    my $title = shift || '';
    my $opts  = shift;

    my $xml =
        "<_${table}_row>"
      . "<table>"
      . $table
      . "</table>"
      . "<swishtitle>"
      . $XMLer->utf8_safe($title)
      . "</swishtitle>"
      . "<_body>";

    for my $col (sort keys %$row)
    {
        my @x = (
                 $XMLer->start_tag($col),
                 $XMLer->utf8_safe($row->{$col}),
                 $XMLer->end_tag($col)
                );

        if ($opts->{desc}->{$col})
        {
            unshift(@x, '<_desc>');
            push(@x, '</_desc>');
        }

        $xml .= join('', @x);
    }
    $xml .= "</_body></_${table}_row>";

    #$self->debug and print STDOUT $xml . "\n";

    return $xml;
}

=head2 title_filter( I<row_hash_ref> )

Override this method if you do not provide a C<title> column in index_sql().
The return value of title_filter() will be used as the C<swishtitle> for the
row's virtual XML document.

=cut

sub title_filter
{
    my $self = shift;
    my $row  = shift;
    return "no title supplied";
}

=head2 row_filter( I<row_hash_ref> )

Override this method if you need to alter the data returned from the db
prior to it being converted to XML for indexing.

This method is called prior to title_filter() so all row data is affected.

B<NOTE:> This is different from the row() method in
the ::Doc subclass. This row_filter() gets called before the Doc object
is created.

=cut

sub row_filter
{
    my $self = shift;
    my $row  = shift;

}

1;

__END__

=pod


=head1 SEE ALSO

L<http://swish-e.org/docs/>

SWISH::Prog, SWISH::Prog::DBI::Doc, Search::Tools::XML


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

Thanks to Atomic Learning for supporting the development of this module.

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
