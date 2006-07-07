package SWISH::Prog::DBI::Doc;
use base qw( SWISH::Prog::Doc );

use Carp;

our $VERSION = '0.01';


=pod

=head1 NAME

SWISH::Prog::DBI::Doc - index DB records with Swish-e

=head1 SYNOPSIS

    
=head1 DESCRIPTION

Subclass of SWISH::Prog::Doc. Inherits all method from that class,
so see that documentation. Only overridden and new methods are documented
here.

=head1 METHODS

=head2 init

Creates row() accessor.

=head2 row

Get/set row hash ref fetched from db. Useful for creating *_filter methods.

B<NOTE:> This row() method is not to be confused with the SWISH::Prog::DBI row_filter()
method.

=cut


sub init
{
    my $self = shift;
    $self->mk_accessors('row');   
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
