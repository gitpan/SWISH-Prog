package SWISH::Prog::QueryParser;
use strict;
use warnings;
use base qw( Search::Tools::QueryParser );
use Carp;
use SWISH::Prog::Query;

our $VERSION = '0.28';

__PACKAGE__->mk_accessors(
    qw(
        config
        ),
);

=head1 NAME

SWISH::Prog::QueryParser - turn text strings into Query objects

=head1 SYNOPSIS

 my $parser = SWISH::Prog::QueryParser->new(
        charset         => 'iso-8859-1',
        phrase_delim    => '"',
        and_word        => 'and',
        or_word         => 'or',
        not_word        => 'not',
        wildcard        => '*',
        stopwords       => [],
        ignore_case     => 1,
        query_class     => 'SWISH::Prog::Query',
        config          => $swish_prog_config,
        default_field   => 'swishdefault',
    );
 my $query = $parser->parse( 'foo not bar or bing' );

=head1 DESCRIPTION

SWISH::Prog::QueryParser turns text strings into Query objects.
The query class defaults to SWISH::Prog::Query but you can
set it in the new() method.

This class depends on Search::Tools::QueryParser for the heavy lifting.
See the documentation for Search::Tools::QueryParser for details
on affecting the parsing behaviour.

=head1 METHODS

Only new or overridden methods are documented here.
See Search::Tools::QueryParser.

=head2 init

Called internally by new().

=cut

sub init {
    my $self = shift;
    my %args = @_;
    if ( !defined $args{query_class} ) {
        $args{query_class} = 'SWISH::Prog::Query';
    }
    if ( !defined $args{default_field} ) {
        $args{default_field} = 'swishdefault';
    }
    $self->SUPER::init(%args);

    if ( !$self->config ) {
        croak "SWISH::Prog::Config object required";
    }
}

=head2 config

A SWISH::Prog::Config object. Set this in new().

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
