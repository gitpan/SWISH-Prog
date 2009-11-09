package SWISH::Prog::Native::Indexer;
use strict;
use warnings;
use base qw( SWISH::Prog::Indexer );
use Carp;
use File::Temp ();
use SWISH::Prog::Native::InvIndex;
use SWISH::Prog::Config;
use Scalar::Util qw( blessed );

our $VERSION = '0.29';

my $invindex_class = 'SWISH::Prog::Native::InvIndex';

__PACKAGE__->mk_accessors(qw( fh exe opts ));

=head1 NAME

SWISH::Prog::Native::Indexer - wrapper around Swish-e binary

=head1 SYNOPSIS

 use SWISH::Prog::Native::Indexer;
 my $indexer = SWISH::Prog::Native::Indexer->new(
        invindex    => SWISH::Prog::Native::InvIndex->new,
        config      => SWISH::Prog::Config->new,
        count       => 0,
        clobber     => 1,
        flush       => 10000,
        started     => time(),
 );
 $indexer->start;
 for my $doc (@list_of_docs) {
    $indexer->process($doc);
 }
 $indexer->finish;


=head1 DESCRIPTION

The Native Indexer is a wrapper around the swish-e version 2.x binary tool.

=head1 METHODS

=head2 new

Create indexer object. All the following parameters are also accessor methods.

=over

=item index

A SWISH::Prog::InvIndex::Native object.

=item config

A SWISH::Prog::Config object.

=item exe

The path to the C<swish-e> executable. If empty, will just look in $ENV{PATH}.

=item verbose

Takes same args as C<swish-e -v> option.

=item warnings

Takes same args as C<swish-e -W> option.

=item opts

String of options passed directly to the swish-e program.

=back

=cut

=head2 init

Initialize object. Called by new().

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

    # default config
    $self->{config} ||= SWISH::Prog::Config->new;

    # default index
    $self->{invindex} ||= $invindex_class->new;

    if ( $self->{invindex} && !blessed( $self->{invindex} ) ) {
        $self->{invindex} = $invindex_class->new( path => $self->{invindex} );
    }

    unless ( $self->invindex->isa($invindex_class) ) {
        croak ref($self) . " requires $invindex_class-derived object";
    }

    $self->{exe} ||= 'swish-e';    # let PATH find it

}

=head2 swish_check

Returns true if the exe() executable works, false otherwise.

=cut

sub swish_check {
    my $self = shift;
    my $cmd  = $self->exe . " -V";
    chomp( my @vers = `$cmd` );
    if ( !@vers ) {
        return 0;
    }
    return $vers[0];
}

=head2 start( [cmd] )

Start the indexer on its merry way. Stores the filehandle
in fh().

Returns the $indexer object.

You likely don't want to pass I<cmd> in but let start() construct
it for you.

=cut

sub start {
    my $self = shift;
    $self->SUPER::start(@_);

    my $index = $self->invindex->file;
    my $v     = $self->verbose || 0;
    my $w     = $self->warnings || 0;    # suffer the peril!
    my $opts  = $self->opts || '';
    my $exe   = $self->exe;

    my $cmd = shift || "$exe $opts -f $index -v$v -W$w -S prog -i stdin";

    if ( !$self->config->file ) {
        $self->config->write2;
    }
    my $config_file = $self->config->file;
    $cmd .= ' -c ' . $config_file;

    $self->debug and carp "opening: $cmd";

    $| = 1;

    open( SWISH, "| $cmd" ) or croak "can't exec $cmd: $!\n";

    # must print bytes as is even if swish-e won't index them as UTF-8
    binmode( SWISH, ':raw' );

    $self->fh( *SWISH{IO} );

    return $self;
}

=head2 fh

Get or set the open() filehandle for the swish-e process. B<CAUTION:>
don't set unless you know what you're doing.

You can print() to the filehandle using the SWISH::Prog index() method.
Or do it directly like:

 print { $indexer->fh } "your headers and body here";
 
The filehandle is close()'d by the finish() method.

=cut

=head2 finish

Close the open fh() filehandle and check for any errors.

Called by the magic DESTROY method so $indexer will finish()
whenever it goes out of scope.

=cut

sub DESTROY {
    shift->finish();
}

sub finish {
    my $self = shift;
    return 1 unless $self->fh;

    # close indexer filehandle
    my $e = close( $self->fh );
    unless ($e) {
        if ( $? == 0 ) {

            # false positive ??
            return;
        }

        carp "error $e: can't close indexer (\$?: $?): $!\n";

        if ( $? == 256 ) {

            # no docs indexed
            # TODO remove temp indexes

        }

    }

    # write header
    $self->config->write3(
        $self->invindex->path->file('swish.xml')->stringify );

}

=head2 merge( @I<SWISH::Prog::Native::InvIndex objects> )

merge() will merge @I<SWISH::Prog::Index::Native objects>
together with the index named in the calling object.

Returns the $indexer object on success, 0 on failure.

 # TODO fix this
 
=cut

sub merge {
    my $self = shift;
    if ( !@_ ) {
        croak "merge() requires some indexes to work with";
    }

    # we want a collection of filenames to work with
    my @names;
    for (@_) {
        if ( ref($_) && $_->isa(__PACKAGE__) ) {
            push( @names, $_->name );
        }
        elsif ( ref($_) ) {
            croak "$_ is not a " . __PACKAGE__ . " object";
        }
        else {
            push( @names, $_ );
        }
    }

    if ( scalar(@names) > 60 ) {
        carp "Likely too many indexes to merge at one time!"
            . "Your OS may have an open file limit.";
    }
    my $m = join( ' ', @names );
    my $i = $self->name    || 'index.swish-e'; # TODO different default name??
    my $v = $self->verbose || 0;
    my $w    = $self->warnings || 0;           # suffer the peril!
    my $opts = $self->opts     || '';
    my $exe  = $self->exe      || 'swish-e';

    # we can't replace the index in-place
    # so we create a new temp index, then mv() back
    my $tmp     = $self->new( name => File::Temp->new->filename );
    my $tmpname = $tmp->name;
    my $cmd     = "$exe $opts -v$v -W$w -M $i $m $tmpname 2>&1";

    my $config_file = $self->config->file;
    if ($config_file) {
        $cmd .= ' -c ' . $config_file;
    }

    $self->debug and carp "opening: $cmd";

    $| = 1;

    open( SWISH, "$cmd  |" )
        or croak "merge() failed: $!\n";

    while (<SWISH>) {
        print STDERR $_ if $self->debug;
    }

    close(SWISH) or croak "can't close merge(): $cmd: $!\n";

    $tmp->mv( $self->name ) or croak "mv() of temp merge index failed";

    return $self;
}

=head2 process( I<$doc> )

process() will parse and index I<$doc>. I<$doc> should be a 
SWISH::Prog::Doc instance.

Will croak() on failure.

=cut

sub process {
    my $self = shift;
    my $doc  = $self->SUPER::process(@_);

    print { $self->fh } $doc
        or croak "failed to print to filehandle " . $self->fh . ": $!\n";

    return $doc;
}

=head2 add( I<doc> )

Add I<doc> to the index.

 # TODO fix
 
=cut

sub add {
    my $self = shift;
    my $doc = shift or croak "need SWISH::Prog::Doc object to add()";
    unless ( $doc->isa('SWISH::Prog::Doc') ) {
        croak "$doc is not a SWISH::Prog::Doc object";
    }

    # it would be nice if the btree flag was accessible somehow via
    # swish-e or the API.
    # instead, we rely on the user to set it in $self->format

    if ( $self->format eq 'native2' ) {
        my $tmp = $self->new(
            name     => File::Temp->new->filename,
            config   => $self->config,
            verbose  => $self->verbose,
            warnings => $self->warnings
        );
        $tmp->run;
        print { $tmp->fh } $doc
            or croak "failed to print to filehandle " . $tmp->fh . ": $!\n";

        $self->merge($tmp)
            or croak "failed to merge " . $tmp->name . " with " . $self->name;

        $tmp->rm or carp "error cleaning up tmp index";

    }
    elsif ( $self->format eq 'btree2' ) {

        # TODO
        croak $self->format . " format is not currently supported.";
    }
    else {
        croak $self->format . " format is not currently supported.";
    }

    return $self;
}

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 BUGS

Please report any bugs or feature requests to C<bug-swish-prog at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SWISH-Prog>.  
I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SWISH::Prog


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SWISH-Prog>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SWISH-Prog>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SWISH-Prog>

=item * Search CPAN

L<http://search.cpan.org/dist/SWISH-Prog/>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 SEE ALSO

L<http://swish-e.org/>
