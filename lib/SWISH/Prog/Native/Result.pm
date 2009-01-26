package SWISH::Prog::Native::Result;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );

__PACKAGE__->mk_accessors(
    qw( swishdocpath swishlastmodified swishtitle swishdescription swishrank ));

our $VERSION = '0.25';

=head1 NAME

SWISH::Prog::Native::Result - result class for SWISH::API::Object

=head1 SYNOPSIS

 # see SWISH::Prog::Result

=head1 DESCRIPTION

The Native Result implements the SWISH::Prog::Result API for 
SWISH::API::Object results.

=head1 METHODS

=cut

=head2 uri

Alias for swishdocpath().

=head2 mtime

Alias for swishlastmodified().

=head2 title

Alias for swishtitle().

=head2 summary

Alias for swishdescription().

=head2 score

Alias for swishrank().

=cut

sub uri     { shift->swishdocpath }
sub mtime   { shift->swishlastmodified }
sub title   { shift->swishtitle }
sub summary { shift->swishdescription }
sub score   { shift->swishrank }

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

