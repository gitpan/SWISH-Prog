package SWISH::Prog::InvIndex::Meta;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );

our $VERSION = '0.23';

# index metadata. read/write libswish3 file xml format.
#

1;

__END__

=pod

=head1 NAME

SWISH::Prog::InvIndex::Meta - read/write InvIndex metadata

=head1 SYNOPSIS

 use SWISH::Prog::InvIndex;
 my $index = SWISH::Prog::InvIndex->new(path => 'path/to/index');
 print $index->meta;  # prints $index->meta->as_string
 
=head1 DESCRIPTION

A SWISH::Prog::InvIndex::Meta object represents the metadata for an
InvIndex.

=head1 METHODS

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

