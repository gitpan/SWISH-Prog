package SWISH::Prog::Indexer;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Scalar::Util qw( blessed );
use Carp;

our $VERSION = '0.23';

__PACKAGE__->mk_accessors(qw( invindex config count clobber flush started ));

=pod

=head1 NAME

SWISH::Prog::Indexer - base indexer class

=head1 SYNOPSIS

 use SWISH::Prog::Indexer;
 my $indexer = SWISH::Prog::Indexer->new(
        invindex    => SWISH::Prog::InvIndex->new,
        config      => SWISH::Prog::Config->new,
        count       => 0,
        clobber     => 1,
        flush       => 10000,
        started     => time()
 );
 $indexer->start;
 for my $doc (@list_of_docs) {
    $indexer->process($doc);
 }
 $indexer->finish;
 
=head1 DESCRIPTION

SWISH::Prog::Indexer is a base class implementing the simplest of indexing
APIs. It is intended to be subclassed, along with InvIndex, for each
IR backend library.

=head1 METHODS

=head2 new( I<params> )

Constructor. See the SYNOPSIS for default options.

=head2 start

Opens the invindex() objet and sets the started() time to time().

=cut

sub start {
    my $self = shift;
    $self->invindex->open;
    $self->{started} = time();
}

=head2 process( I<doc> )

I<doc> should be a SWISH::Prog::Doc-derived object.

process() should implement whatever the particular IR library
API requires.

=cut

sub process {
    my $self = shift;
    my $doc  = shift;
    unless ( $doc && blessed($doc) && $doc->isa('SWISH::Prog::Doc') ) {
        croak "SWISH::Prog::Doc object required";
    }

    $self->start unless $self->started;

    $self->{count}++;

    return $doc;
}

=head2 finish

Closes the invindex().

=cut

sub finish {
    my $self = shift;
    $self->invindex->close;
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
