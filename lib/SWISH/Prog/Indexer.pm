package SWISH::Prog::Indexer;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Scalar::Util qw( blessed );
use Carp;

our $VERSION = '0.27';

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

I<params> may include the following keys, each of which is also an
accessor method:

=over

=item clobber

Overrite any existing InvIndex.

=item config

A SWISH::Prog::Config object.

=item flush

The number of indexed docs at which in-memory changes 
should be written to disk.

=item invindex

A SWISH::Prog::InvIndex object.

=back

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

=head2 count

Returns the number of documents processed.

=head2 started

The time at which the Indexer object was created. Returns a Unix epoch
integer.

=cut

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 BUGS

Please report any bugs or feature requests to C<bug-swish-prog at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SWISH-Prog>.  
I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SWISH::Prog


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SWISH-Prog>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SWISH-Prog>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SWISH-Prog>

=item * Search CPAN

L<http://search.cpan.org/dist/SWISH-Prog/>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 SEE ALSO

L<http://swish-e.org/>
