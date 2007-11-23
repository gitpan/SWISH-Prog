package SWISH::Prog::DBI;

use strict;
use warnings;

use Carp;
use Data::Dump qw/dump/;
use DBI;
use Search::Tools::XML;
use SWISH::Prog::DBI::Doc;

use base qw( SWISH::Prog );

__PACKAGE__->mk_accessors(qw/ table_meta db title alias_columns /);

our $VERSION = '0.08';
our $XMLer   = Search::Tools::XML->new;

=pod

=head1 NAME

SWISH::Prog::DBI - index DB records with Swish-e

=head1 SYNOPSIS
    
    use SWISH::Prog::DBI;
    use Carp;
    
    my $prog_dbi = SWISH::Prog::DBI->new(
        db => [
            "DBI:mysql:database=movies;host=localhost;port=3306",
            'some_user', 'some_secret_pass',
            {
                RaiseError  => 1,
                HandleError => sub { confess(shift) },
            }
        ],
        alias_columns => 1
    );
    
    $prog_dbi->create(
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

=head1 METHODS

=head2 new( db => I<DBI_connect_info>, alias_columns => 0|1 )

Create new indexer object. I<DBI_connect_info> is passed
directly to DBI's connect() method, so see the DBI docs for syntax.
If I<DBI_connect_info> is a DBI handle object, it is accepted as is.
If I<DBI_connect_info> is an array ref, it will be dereferenced and
passed to connect(). Otherwise it will be passed to connect as is.

The C<alias_columns> flag indicates whether all columns should be searchable
under the default MetaName of swishdefault. The default is 1 (true). This
is B<not> the default behaviour of swish-e; this is a feature of SWISH::Prog.

B<NOTE:> The new() method simply inherits from SWISH::Prog, so any params
valid for that method() are allowed here.

=head2 init

Initialize object. This overrides SWISH::Prog init() base method.

=cut

sub init
{
    my $self = shift;

    # verify DBI connection
    if (defined($self->db))
    {

        if (ref($self->db) eq 'ARRAY')
        {
            $self->db(DBI->connect(@{$self->{db}}));
        }
        elsif (ref($self->db) && $self->db->isa('DBI::db'))
        {

            # do nothing
        }
        else
        {
            $self->db(DBI->connect($self->db));
        }
    }
    else
    {
        croak "need DBI connection info in db param";
    }

    $self->{debug} ||= $ENV{PERL_DEBUG} || 0;
    $self->{alias_columns} = 1 unless exists $self->{alias_columns};

    # cache meta
    $self->info;

    # unless metanames are defined, use all the column names from all
    # our discovered tables.
    my $m = $self->config->MetaNames;
    unless (@$m)
    {
        for my $table (keys %{$self->table_meta})
        {
            $self->config->MetaNames(
                              sort keys %{$self->table_meta->{$table}->{cols}});
        }
    }
    

    # alias the top level tags to that default search will match any metaname in any table
    if ($self->alias_columns)
    {
        $self->config->MetaNameAlias(
                                     'swishdefault '
                                       . join(' ',
                                              map { '_' . $_ . '_row' }
                                                sort keys %{$self->table_meta}),
                                     1  # always append
                                    );
    }

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
    $self->config->MetaNames('table');

    # save all row text in the swishdescription property for excerpts
    $self->config->StoreDescription('XML* <_desc>');

    # TODO get version
    $self->config->write2;

    $self->SUPER::init_indexer();

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

    return if $self->table_meta;

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

    $self->table_meta(\%meta);
    $sth->finish;
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
    
    $sth->finish;
    
    return \%cols;
}

=pod

=head2 table_meta

Get/set all the table/column info for the current db.


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

B<NOTE:> create() just loops over all the relevant tables and 
calls index_sql() to actually create each
index. If you want to tailor your SQL (using JOINs etc.) then you probably
want to call index_sql() directly.

Returns number of rows indexed.

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
        @tables = sort keys %{$self->table_meta};
    }

    my $count = 0;

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
            @cols = sort keys %{$self->table_meta->{$table}->{cols}};
        }

        $count +=
          $self->index_sql(
                       name => $table . ".index",
                       sql => "SELECT `" . join('`,`', @cols) . "` FROM $table",
                       table => $table,
                       desc  => $opts{tables}->{$table}->{desc} || {},
                       title => $opts{tables}->{$table}->{title} || ''
          );

    }

    return $count;

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

=item desc

Which columns to include in C<swishdescription> property. Default is none.
Should be a hashref with column names as keys.

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

    while (my $row = $sth->fetchrow_hashref)
    {

        $self->row_filter($row);

        my $title =
          exists $row->{$opts{title}}
          ? $row->{$opts{title}}
          : $self->title_filter($row);

        my $xml =
          $self->row2xml($XMLer->tag_safe($opts{table}), $row, $title, \%opts);

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
    }
    
    $sth->finish;

    return $counter;

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

See FILTERS section.

=cut

sub row_filter
{
    my $self = shift;
    my $row  = shift;

}

1;

__END__

=head1 FILTERS

There are several filtering methods in this module. Here's a summary of what they do
and when they are called, so you have a better idea of how to best use them. Pay special
attention to those called before converting the row to XML as opposed to after conversion.

=head2 row_filter

Called by index_sql() for each row fetched from the database. This is the first filter
called in the chain. Called before the row is converted to XML.

=head2 title_filter

Called by index_sql() after row_filter() but only if an explicit C<title> opt param was not
passed to index_sql(). Called before the row is converted to XML.

=head2 SWISH::Prog::DBI::Doc *_filter() methods

Each of the normal SWISH::Prog::Doc attributes has a *_filter() method. These are called
after the row is converted to XML. See SWISH::Prog::Doc.

B<NOTE:> There is not a SWISH::Prog::DBI::Doc row_filter() method.

=head2 filter

The normal SWISH::Prog filter() method is called as usual just before passing to ok()
inside index(). Called after the row is converted to XML.


=head1 ENCODINGS

Since Swish-e version 2 does not support UTF-8 encodings, you may need to convert or
transliterate your text prior to indexing. Swish-e offers the TranslateCharacters config
option, but that does not work well with multi-byte characters.

Here's one way to handle the issue. Use Search::Tools::Transliterate and the row_filter()
method to convert your UTF-8 text to single-byte characters. You can do this by subclassing
SWISH::Prog::DBI and overriding the row_filter() method.

Example:

 package My::DBI;
 use base qw( SWISH::Prog::DBI );

 use POSIX qw(locale_h);
 use locale;
 use Encode;
 use Search::Tools::Transliterate;
 my $trans = Search::Tools::Transliterate->new;
 my ($charset) = (setlocale(LC_CTYPE) =~ m/^.+?\.(.+)/ || 'iso-8859-1');

 sub row_filter
 {
    my $self = shift;
    my $row  = shift;

    # We transliterate everything in each row and append as a charset column.
    # This means we can search for it but it'll not show in any property.
    # Instead we'll get the UTF-8 text in the property value.
    # The downside is that you can't do 'meta=asciitext' because the charset string
    # is not stored under any but the swishdefault metaname.
    # You could get around that by using MetaNameAlias in config() to alias
    # each column to column_charset.
    
    for (keys %$row)
    {
        # if it's not already UTF-8, make it so.
        unless ($trans->is_valid_utf8($row->{$_}))
        {
            $row->{$_} = Encode::encode_utf8(Encode::decode($charset, $row->{$_}, 1));
        }
        
        # then transliterate to single-byte chars
        $row->{$_ . '_' . $charset} = $trans->convert($row->{$_});
    }

 }

 1;
 
 use My::DBI;
 
 my $dbi_prog = My::DBI->new(
                    config => SWISH::Config->new(     
             # also use Swish-e's feature so that all text is searchable as ASCII
                      TranslateCharacters => ':ascii:'
                                ),
                                
                            );
                            
 $dbi_prog->create;
                    

=head1 SEE ALSO

L<http://swish-e.org/docs/>

SWISH::Prog, SWISH::Prog::DBI::Doc, Search::Tools


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

Thanks to Atomic Learning for supporting the development of this module.

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
