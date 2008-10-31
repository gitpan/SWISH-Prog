package SWISH::Prog::Queue;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;

our $VERSION = '0.21';

=pod

=head1 NAME

SWISH::Prog::Queue - simple in-memory FIFO queue class

=head1 SYNOPSIS

 use SWISH::Prog::Queue;
 my $queue = SWISH::Prog::Queue->new;
 
 $queue->put( 'foo' );
 $queue->size;          # returns number of items in queue (1)
 $queue->peek;          # returns 'foo' (next value for get())
 $queue->get;           # returns 'foo' and removes it from queue

=head1 DESCRIPTION

SWISH::Prog::Queue is basically a Perl array, but it defines an API
that can be implemented using any kind of storage and logic you want.
One example would be a database that tracks items to be evaluated, or a flat
file list.

=head1 METHODS

See SWISH::Prog::Class.

=cut

=head2 init

Overrides base method.

=cut

sub init {
    my $self = shift;
    $self->{q} ||= [];
}

=head2 put( I<item> )

Add I<item> to the queue. Default is to push() it to end of queue.

=cut

sub put {
    my $self = shift;
    push( @{ $self->{q} }, @_ );
}

=head2 get

Returns the next item. Default is to shift() it from the front of the queue.

=cut

sub get {
    return shift( @{ $_[0]->{q} } );
}

=head2 peek

Returns the next item value, but leaves it on the stack.

=cut

sub peek {
    return $_[0]->{q}->[0];
}

=head2 size

Returns the number of items currently in the queue.

=cut

sub size {
    return scalar( @{ $_[0]->{q} } );
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
