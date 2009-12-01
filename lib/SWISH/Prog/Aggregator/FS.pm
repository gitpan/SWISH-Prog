package SWISH::Prog::Aggregator::FS;
use strict;
use warnings;
use base qw( SWISH::Prog::Aggregator );

use Carp;
use File::Slurp;
use File::Find;

our $VERSION = '0.31';

=pod

=head1 NAME

SWISH::Prog::Aggregator::FS - filesystem aggregator

=head1 SYNOPSIS

 use SWISH::Prog::Aggregator::FS;
 my $fs = SWISH::Prog::Aggregator::FS->new(
        indexer => SWISH::Prog::Indexer->new
    );
    
 $fs->indexer->start;
 $fs->crawl( $path );
 $fs->indexer->finish;
 
=head1 DESCRIPTION

SWISH::Prog::Aggregator::FS is a filesystem aggregator implementation
of the SWISH::Prog::Aggregator API. It is similar to the DirTree.pl
script in the Swish-e 2.4 distribution.

=cut

=head1 METHODS

See SWISH::Prog::Aggregator.

=head2 init

Implements the base init() method called by new().

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

    # read from $self->config and set some flags
    # TODO FileRules, FileMatch

    # create .ext regex to match in file_ok()
    if ( $self->config->IndexOnly ) {
        my $re = join( '|',
            grep {s/^\.//} split( m/\s+/, $self->config->IndexOnly ) );
        $self->{_ext_re} = qr{($re)}io;
    }
    else {
        $self->{_ext_re} = $SWISH::Prog::Utils::ExtRE;
    }

    # if running with SWISH::3, instantiate one for the slurp advantage
    if ( $ENV{SWISH3} ) {
        $self->{_swish3} = SWISH::3->new;
    }

}

=head2 file_ok( I<full_path> )

Check I<full_path> before fetch()ing it.

Returns 0 if I<full_path> should be skipped.

Returns file extension of I<full_path> if I<full_path> should be processed.

=cut

sub file_ok {
    my $self      = shift;
    my $full_path = shift;
    my $stat      = shift;

    $self->debug and print "checking file $full_path\n";

    my ( $path, $file, $ext )
        = SWISH::Prog::Utils->path_parts( $full_path, $self->{_ext_re} );

    return 0 unless $ext;
    return 0 if $full_path =~ m![\\/](\.svn|RCS)[\\/]!; # TODO configure this.
    return 0 if $file =~ m/^\./;

    #carp "parsed file: $file\npath: $path\next: $ext";

    $stat ||= [ stat($full_path) ];
    return 0 unless -r _;
    return 0 if -d _;

    $self->debug and warn "  $full_path -> ok\n";

    return $ext;
}

=head2 dir_ok( I<directory> )

Called by find() for all directories. You can control
the recursion into I<directory> via the config() params

 TODO
 
=cut

sub dir_ok {
    my $self = shift;
    my $dir  = shift;
    my $stat = shift || [ stat($dir) ];
    return 0 unless -d _;
    return 0 if $dir =~ m!/\.!;
    return 0 if $dir =~ m/^\.[^\.]/;        # could be ../foo
    return 0 if $dir =~ m!/(\.svn|RCS)/!;

    $self->verbose and print "$dir .. ok\n";

    1;                                      # TODO esp RecursionDepth
}

=head2 get_doc( I<file_path> [, I<stat>, I<ext> ] )

Returns a doc_class() instance representing I<file_path>.

=cut

sub get_doc {
    my $self = shift;
    my $url = shift or croak "file path required";
    my ( $stat, $ext ) = @_;
    my $buf;

    # the SWISH::3->slurp is about 50% faster
    # but obviously only available if SWISH::3 is loaded.
    if ( $self->{_swish3} ) {
        eval { $buf = $self->{_swish3}->slurp($url) };
    }
    else {
        eval { $buf = read_file( $url, binmode => ':raw' ) };
    }

    if ($@) {
        carp "unable to read $url - skipping";
        return;
    }

    $stat ||= [ stat($url) ];

    # TODO SWISH::3 has this function too.
    # might be faster since no OO overhead.
    my $type = SWISH::Prog::Utils->mime_type( $url, $ext );

    return $self->doc_class->new(
        url     => $url,
        modtime => $stat->[9],
        content => $buf,
        type    => $type,
        size    => $stat->[7],
        debug   => $self->debug
    );

}

sub _do_file {
    my $self = shift;
    my $file = shift;
    $self->{count}++;
    if ( my $ext = $self->file_ok($file) ) {
        my $doc = $self->get_doc( $file, [ stat(_) ], $ext );
        $self->swish_filter($doc);
        $self->{indexer}->process($doc);
    }
    else {
        $self->debug and warn "skipping $file\n";
    }
}

#
# the basic wanted() code here based on Bill Moseley's DirTree.pl,
# part of the Swish-e 2.4 distrib.

=head2 crawl( I<paths_or_files> )

Crawl the filesystem recursively within I<paths_or_files>, processing
each document specified by the config().

=cut

sub crawl {
    my $self = shift;

    my @paths = @_;

    my @files = grep { !-d } @paths;
    my @dirs  = grep {-d} @paths;

    for my $f (@files) {
        $self->_do_file($f);
    }

    # TODO set some flags here for filtering out files/dirs
    # based on $self->indexer->config.

    if (@dirs) {

        find(
            {   wanted => sub {

                    my $path = $File::Find::name;

                    if (-d) {
                        unless ( $self->dir_ok( $path, [ stat(_) ] ) ) {
                            $File::Find::prune = 1;
                            return;
                        }

                        #warn "$path\n";
                        return;
                    }
                    else {

                        #warn "$path\n";
                    }

                    $self->_do_file($path);

                },
                no_chdir => 1,
                follow   => $self->config->FollowSymLinks,

            },
            @dirs
        );
    }

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

=item * Mailing list

L<http://lists.swish-e.org/listinfo/users>

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
