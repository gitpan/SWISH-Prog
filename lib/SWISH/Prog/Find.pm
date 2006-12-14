package SWISH::Prog::Find;

use strict;
use warnings;

use Carp;
use Data::Dump qw( pp );
use File::Find;

our $VERSION = '0.02';

#
# the basic wanted() code here based on Bill Moseley's DirTree.pl,
# part of the Swish-e 2.x distrib.
# the 0.01 release of this module used Path::Class::Iterator
# which is up to 6x slower than File::Find due (in part) to the multitude
# of method call overhead. So we just use good ol' File::Find and wrap
# it around our basic methods

sub files
{
    my $self  = shift;
    my @paths = @_;

    my @files = grep { !-d } @paths;
    my @dirs  = grep { -d } @paths;

    for my $f (@files)
    {
        if (my $ext = $self->url_ok($f))
        {
            my $doc = $self->fetch($f, [stat(_)], $ext);
            $self->index($doc);
        }
    }

    if (@dirs)
    {

        find(
            {
             wanted => sub {

                 my $path = $File::Find::name;

                 if (-d)
                 {
                     unless ($self->dir_ok($path, [stat(_)]))
                     {
                         $File::Find::prune = 1;
                         return;
                     }
                     print "$path\n" if $self->verbose;
                     return;
                 }
                 else
                 {
                     print "$path\n" if $self->verbose > 1;
                 }

                 if (my $ext = $self->url_ok($path, [stat(_)]))
                 {
                     my $doc = $self->fetch($path, [stat(_)], $ext);
                     $self->index($doc);
                 }

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

=pod

=head1 NAME

SWISH::Prog::Find - search one or more directory trees for files to index

=head1 SYNOPSIS

    use SWISH::Prog;
    my $indexer = SWISH::Prog->new;
    $indexer->find('some/dir');

=head1 DESCRIPTION

SWISH::Prog::Find uses a simple File::Find wanted() call to recursively 
index the filesystem.

=head1 METHODS

=head2 files( $prog, @I<paths> )

Recursive through @I<paths> and call the basic Prog methods: dir_ok(), url_ok(),
fetch() and index().

I<paths> may be files or directories. Any files will be handled before any directories.
 
=head1 REQUIREMENTS

L<File::Find>

=head1 SEE ALSO

L<http://swish-e.org/docs/>,
L<SWISH::Prog>

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
