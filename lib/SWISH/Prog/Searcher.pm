package SWISH::Prog::Searcher;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;
use Scalar::Util qw( blessed );
use SWISH::Prog::QueryParser;

our $VERSION = '0.26';

__PACKAGE__->mk_accessors(
    qw(
        query
        sort_order
        max_hits
        query_class
        query_parser
        invindex
        config
        ),
);

=head1 NAME

SWISH::Prog::Searcher - base searcher class

=head1 SYNOPSIS

 my $searcher = SWISH::Prog::Searcher->new(
                    invindex        => 'path/to/index',
                    query_class     => 'SWISH::Prog::Query',
                    query_parser    => $swish_prog_queryparser,
                    config          => $swish_prog_config,
                    max_hits        => 100,
                    sort_order      => 'swishrank',
                );
                
 my $results = $searcher->search( 'foo bar' );
 while (my $result = $results->next) {
     printf("%4d %s\n", $result->score, $result->uri);
 }

=head1 DESCRIPTION

SWISH::Prog::Searcher is a base searcher class. It defines
the APIs that all SWISH::Prog storage backends adhere to in
returning results from a SWISH::Prog::InvIndex.

=head1 METHODS


=head2 init

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

    # set defaults
    $self->{query_class} ||= 'SWISH::Prog::Query';

    # set up invindex
    if ( !$self->{invindex} ) {
        croak "invindex required";
    }
    if ( !blessed( $self->{invindex} ) ) {

        # assume a InvIndex in the same base class as $self
        my $class = ref($self);
        $class =~ s/::Searcher$/::InvIndex/;
        $self->{invindex}
            = $class->new( path => $self->{invindex}, clobber => 0 );

        #warn "new invindex in $class";

    }
    $self->{invindex}->open_ro;

    # set up config
    # TODO why do we need this?
    # TODO read from invindex/swish.(xml|conf) ?
    if ( !$self->{config} ) {
        croak "config required";
    }

    $self->{query_parser} ||= SWISH::Prog::QueryParser->new(
        query_class => $self->{query_class},
        config      => $self->{config},
    );

    $self->{max_hits} ||= 100;

    return $self;
}

=head2 search( I<query> )

Returns a SWISH::Prog::Results object.

=cut

sub search {
    croak "you must override search() in your subclass";
}

=head2 check_query( I<query> )

Utility method, intended to be called from search().

Example:

 sub search {
     my $self = shift;
     my $args = $self->check_query(@_);
     # $self->query now guaranteed to contain a Query object.
 }

=cut

sub check_query {
    my $self = shift;
    my %args;
    my $query;
    if ( @_ == 1 ) {
        $query = shift;
    }
    else {
        %args  = @_;
        $query = delete $args{query};
    }

    if ( !$query ) {
        croak "query required";
    }

    if ( ref $query and !$query->isa( $self->{query_class} ) ) {
        croak
            "query must inherit from $self->{query_class} or you must set query_class";
    }
    elsif ( !ref $query ) {
        $query = $self->{query_parser}->parse($query);
    }

    $self->{query} = $query;

    return \%args;
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
