package SWISH::Prog::Find;

use strict;
use warnings;

use Carp;
use Data::Dump qw/dump/;

use base qw( Path::Class::Iterator );

our $VERSION = '0.01';

1;
__END__

=pod

=head1 NAME

SWISH::Prog::Find - search one or more directory trees for files to index

=head1 SYNOPSIS

    use SWISH::Prog;
    my $indexer = SWISH::Prog->new;
    my $finder  = $indexer->find('some/dir');
        
    until($finder->done)
    {
        my $doc = $indexer->fetch($finder->next);
        $indexer->index( $doc ) if $indexer->ok( $doc );
    }


=head1 DESCRIPTION

SWISH::Prog::Find is a subclass of L<Path::Class::Iterator>.

=head1 METHODS

=head2 new( I<args> )

 # TODO
 
=head1 REQUIREMENTS

L<Path::Class::Iterator>

=head1 SEE ALSO

L<http://swish-e.org/docs/>

L<SWISH::Prog>, L<Path::Class::Iterator>


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
