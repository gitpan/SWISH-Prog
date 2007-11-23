package SWISH::Prog::Mail::Doc;
use strict;
use warnings;
use base qw( SWISH::Prog::Doc );

our $VERSION = '0.08';

=pod

=head1 NAME

SWISH::Prog::DBI::Mail - index email with Swish-e

=head1 SYNOPSIS

 # see SWISH::Prog::Doc
    
=head1 DESCRIPTION

Subclass of SWISH::Prog::Doc. Inherits all method from that class,
so see that documentation. Only overridden and new methods are documented
here.

=head1 METHODS

=head2 init

Creates mail() accessor.

=head2 mail

Get/set hash ref representing a mail message. Useful for creating *_filter methods.

=cut

__PACKAGE__->mk_accessors('mail');


1;

__END__

=pod

=head1 SEE ALSO

L<http://swish-e.org/docs/>

SWISH::Prog,
SWISH::Prog::Mail


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
