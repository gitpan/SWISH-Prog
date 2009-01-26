package SWISH::Prog::InvIndex::Meta;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;
use XML::Simple;

our $VERSION = '0.25';

__PACKAGE__->mk_accessors(qw( file data invindex ));

# index metadata. read/write libswish3 file xml format.
#

sub init {
    my $self = shift;
    $self->{file} = $self->invindex->path->file('swish.xml');
    $self->{data} = XMLin("$self->{file}");

    #warn Data::Dump::dump( $self->{data} );
}

sub AUTOLOAD {
    my $self   = shift;
    my $method = our $AUTOLOAD;
    $method =~ s/.*://;
    return if $method eq 'DESTROY';

    if ( exists $self->{data}->{$method} ) {
        return $self->{data}->{$method};
    }
    croak "no such Meta key: $method";
}

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

=head2 init

Read and initialize the swish.xml header file.

=cut

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

