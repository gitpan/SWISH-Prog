package SWISH::Prog::Query;
use strict;
use warnings;
use base qw( Search::Tools::Query );
use Carp;

our $VERSION = '0.30';

=head1 NAME

SWISH::Prog::Query - a Query object base class

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
    );
 my $query = $parser->parse( 'foo not bar or bing' );

=head1 DESCRIPTION

SWISH::Prog::Query is a base class representing a query.
You create Query objects and pass them to a Searcher.

=head1 METHODS

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
