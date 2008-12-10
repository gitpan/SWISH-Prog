package SWISH::Prog::Class;
use strict;
use warnings;
use base qw( Class::Accessor::Fast );
use Carp;
use Data::Dump;

our $VERSION = '0.22';

__PACKAGE__->mk_accessors(qw( verbose debug warnings ));

=pod

=head1 NAME

SWISH::Prog::Class - base class for SWISH::Prog classes

=head1 SYNOPSIS

 package My::Class;
 use base qw( SWISH::Prog::Class );
 1;
 
 # see METHODS for what you get for free

=head1 DESCRIPTION

SWISH::Prog::Class is a subclass of Class::Accessor::Fast.
It's a base class useful for making simple accessor/mutator methods.
SWISH::Prog::Class implements some additional methods and features
useful for SWISH::Prog projects.

=head1 METHODS

=head2 new( I<params> )

Constructor. Returns a new object. May take a hash or hashref
as I<params>.

=head2 init

Override init() in your subclass to perform object maintenance at
construction time. Called by new().

=head2 debug

=head2 warnings

=head2 verbose

Get/set flags affecting the verbosity of the program.

=cut

sub new {
    my $class = shift;
    my $opts  = ref( $_[0] ) ? $_[0] : {@_};
    my $self  = $class->SUPER::new($opts);
    $self->{_start} = time();
    unless ( exists $self->{debug} ) {
        $self->{debug} = $ENV{PERL_DEBUG} || 0;
    }
    $self->init;
    return $self;
}

sub init { }

=head2 elapsed

Returns the elapsed time in seconds since object was created.

=cut

sub elapsed {
    return time() - shift->{_start};
}

=head2 dump( [I<data>] )

Returns $self or I<data> (if present) via Data::Dump::dump. Useful for peering
inside an object or other scalar.

=cut

sub dump {
    my $self = shift;
    if (@_) {
        Data::Dump::dump( \@_ );
    }
    else {
        Data::Dump::dump($self);
    }
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
