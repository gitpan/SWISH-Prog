package SWISH::Prog::Cache;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
__PACKAGE__->mk_accessors(qw( cache ));
use Carp;

our $VERSION = '0.25';

=pod

=head1 NAME

SWISH::Prog::Cache - simple in-memory cache class

=head1 SYNOPSIS

 use SWISH::Prog::Cache;
 my $cache = SWISH::Prog::Cache->new;
 $cache->add( foo => 'bar' );
 $cache->has( 'foo' ); # returns true
 $cache->get( 'foo' ); # returns 'bar'
 $cache->delete( 'foo' ); # removes 'foo' from cache and returns 'bar'

=head1 DESCRIPTION

SWISH::Prog::Cache is a simple in-memory caching class. It's basically
just a Perl hash, but implemented as a class so that you can subclass it
and use different storage (e.g. Cache::* modules).

=cut

=head1 METHODS

See SWISH::Prog::Class. Only new or overridden methods are documented here.

=head2 init

Initialize the cache. Called internally by new(). You should not need to
call this yourself.

=cut

sub init {
    my $self = shift;
    $self->{cache} ||= {};
}

=head2 has( I<key> )

Does I<key> exist in cache.

=cut

sub has {
    my $self = shift;
    my $key  = shift;
    defined($key) or croak "key required";
    return exists $self->{cache}->{$key};
}

=head2 get( I<key> )

Returns value for I<key>. Returns undef if has( I<key> ) is false.

=cut

sub get {
    my $self = shift;
    my $key  = shift;
    defined($key) or croak "key required";
    return exists $self->{cache}->{$key} ? $self->{cache}->{$key} : undef;
}

=head2 delete( I<key> )

Delete I<key> from cache.

=cut

sub delete {
    my $self = shift;
    my $key  = shift;
    defined($key) or croak "key required";
    delete $self->{cache}->{$key};
}

=head2 add( I<key> => I<value> )

Add I<key> to cache with value I<value>.

=cut

sub add {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;
    defined($key) or croak "key required";
    $self->{cache}->{$key} = $val;
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
