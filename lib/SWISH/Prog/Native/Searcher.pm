package SWISH::Prog::Native::Searcher;
use strict;
use warnings;
use Carp;
use base qw( SWISH::Prog::Searcher );
use SWISH::API::Object;
use SWISH::Prog::Native::InvIndex;
use SWISH::Prog::Native::Result;

__PACKAGE__->mk_accessors(qw( swish sao_opts result_class ));

our $VERSION = '0.26';

=head1 NAME

SWISH::Prog::Native::Searcher - wrapper for SWISH::API::Object

=head1 SYNOPSIS

 # see SWISH::Prog::Searcher

=head1 DESCRIPTION

The Native Searcher is a thin wrapper around SWISH::API::Object.

=head1 METHODS

=cut

=head2 init

Instantiates the SWISH::API::Object instance and stores it
in the swish() accessor.

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

    $self->{swish} = SWISH::API::Object->new(
        indexes => [ $self->{invindex}->file ],
        class   => $self->{result_class} || 'SWISH::Prog::Native::Result',
        @{ $self->{sao_opts} || [] }
    );

    return $self;
}

=head2 search( I<query> )

Calls the query() method on the internal SWISH::API::Object.
Returns a SWISH::API::Object::Results object.

=cut

sub search {
    my $self = shift;
    return $self->{swish}->query(@_);
}

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
