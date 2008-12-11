package SWISH::Prog::InvIndex::Native;
use strict;
use warnings;
use Carp;
use base qw( SWISH::Prog::InvIndex );
__PACKAGE__->mk_accessors(qw( file ));

our $VERSION = '0.23';

=head1 NAME

SWISH::Prog::InvIndex::Native - the native Swish-e index format

=cut

=head2 init

Sets file() to default index file name C<index.swish-e> unless
it is already set. If already set, confirms that file() is a child
of path().

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    if ( !$self->file ) {
        $self->file( $self->path->file('index.swish-e') );
    }
    else {

        # TODO check that ->file is child of ->path

    }

}

=head2 open

Creates path() if not already existent.

Since the native swish-e behaviour is to always create a temp index
and then rename it on close(), the clobber() attribute is effectively
ignored (always true).

=cut

# TODO open() with SWISH::API ??
sub open {
    my $self = shift;

    if ( -f $self->path ) {
        croak $self->path . " is not a directory.";
    }

    if ( !-d $self->path ) {
        $self->path->mkpath(1);
    }

    1;
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
