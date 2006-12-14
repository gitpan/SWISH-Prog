package SWISH::Prog::Object::Doc;
use base qw( SWISH::Prog::Doc );

use Carp;

our $VERSION = '0.01';


=pod

=head1 NAME

SWISH::Prog::Object::Doc - index Perl objects with Swish-e

=head1 SYNOPSIS

    
=head1 DESCRIPTION

Subclass of SWISH::Prog::Doc. Inherits all method from that class,
so see that documentation. Only overridden and new methods are documented
here.

=head1 METHODS

=head2 init

Creates obj() accessor.

=head2 obj

Get/set object. Useful for creating *_filter methods.

B<NOTE:> This obj() method is not to be confused with the SWISH::Prog::Object obj_filter()
method.

=cut


sub init
{
    my $self = shift;
    $self->mk_accessors('obj');   
}


1;

__END__

=pod

=head1 SEE ALSO

L<http://swish-e.org/docs/>

SWISH::Prog,
SWISH::Prog::DBI


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

Thanks to Atomic Learning for supporting the development of this module.

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
