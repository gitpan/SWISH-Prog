package SWISH::Prog::Aggregator::Spider::UA;
use strict;
use warnings;
use base qw( WWW::Mechanize );
use Carp;
use Data::Dump qw( dump );
use Search::Tools::UTF8;

=pod

=head1 NAME

SWISH::Prog::Aggregator::Spider::UA - spider user agent

=head1 SYNOPSIS

 use SWISH::Prog::Aggregator::Spider::UA;
 my $ua = SWISH::Prog::Aggregator::Spider::UA->new;
 
 # $ua is a WWW::Mechanize object

=head1 DESCRIPTION

SWISH::Prog::Aggregator::Spider::UA is a subclass of 
WWW::Mechanize.

=head1 METHODS

=head2 get( I<uri>, I<delay> )

sleep() I<delay> seconds before fetching I<uri>.

=cut

sub get {
    my $self  = shift;
    my $uri   = shift or croak "URI required";
    my $delay = shift;
    if ($delay) {
        sleep($delay);
    }
    return $self->SUPER::get($uri);
}

=head2 title

Returns document title. Overrides base method to verify that UTF-8
flag is set correctly on the response content.

=cut

sub title {
    my $self = shift;
    return unless $self->is_html;

    require HTML::HeadParser;
    my $p = HTML::HeadParser->new;

    # the standard title() method does not check to see if utf-8 is
    # flagged as such by perl, and so HTML::HeadParser throws warning.
    # So we trust the content-type header and
    # verify that the utf-8 flag is on.
    if ( $self->response->header('content-type') =~ m/utf-8/i ) {
        $p->parse( to_utf8( $self->content ) );
    }
    else {
        $p->parse( $self->content );
    }
    return $p->header('Title');
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
