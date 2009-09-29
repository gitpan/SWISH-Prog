package SWISH::Prog::Native::Searcher;
use strict;
use warnings;
use Carp;
use base qw( SWISH::Prog::Searcher );
use SWISH::API::Object;
use SWISH::Prog::Native::InvIndex;
use SWISH::Prog::Native::Result;

__PACKAGE__->mk_accessors(qw( swish sao_opts result_class ));

our $VERSION = '0.27';

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
