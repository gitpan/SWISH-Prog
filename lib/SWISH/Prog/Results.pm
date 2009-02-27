package SWISH::Prog::Results;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;

our $VERSION = '0.26';

__PACKAGE__->mk_accessors(
    qw(
        hits
        ),
);

=head1 NAME

SWISH::Prog::Results - base results class

=head1 SYNOPSIS

 my $searcher = SWISH::Prog::Searcher->new(
                    invindex        => 'path/to/index',
                    query_class     => 'SWISH::Prog::Query',
                    query_parser    => $swish_prog_queryparser,
                );
                
 my $results = $searcher->search( 'foo bar' );
 while (my $result = $results->next) {
     printf("%4d %s\n", $result->score, $result->uri);
 }

=head1 DESCRIPTION

SWISH::Prog::Results is a base results class. It defines
the APIs that all SWISH::Prog storage backends adhere to in
returning results from a SWISH::Prog::InvIndex.

=head1 METHODS

=cut

=head2 init

=cut

=head2 next

Return the next Result.

=cut

sub next {
    croak "must override next() in your subclass";
}

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut
