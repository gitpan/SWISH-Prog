package SWISH::Prog;
use 5.008003;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;
use Data::Dump qw( dump );
use Scalar::Util qw( blessed );
use SWISH::Prog::Config;
use SWISH::Prog::InvIndex;

our $VERSION = '0.40';

__PACKAGE__->mk_accessors(qw( aggregator test_mode ));

# each $swishProg hasa aggregator, which hasa indexer and hasa invindex

=pod

=head1 NAME

SWISH::Prog - information retrieval application framework

=head1 SYNOPSIS

  use SWISH::Prog;
  my $program = SWISH::Prog->new(
    invindex    => 'path/to/myindex',
    aggregator  => 'fs',
    indexer     => 'native',
    config      => 'some/swish/config/file',
    filter      => sub { print $_[0]->url . "\n" },
  );
                
  $program->run('some/dir');
  
  print $program->count . " documents indexed\n";
          

=head1 DESCRIPTION

B<NOTE: As of version 0.20 this API has been completely redesigned
from previous versions.>

SWISH::Prog is a full-text search framework based on Swish-e.
SWISH::Prog handles document and data aggregation and indexing.

The name "SWISH::Prog" comes from the Swish-e -S prog feature.
"prog" is short for "program". SWISH::Prog makes it easy to
write indexing and search programs.

B<The API is a work in progress and subject to change.>

=head1 METHODS

All of the following methods may be overridden when subclassing
this module.


=head2 init

Overrides base SWISH::Prog::Class init() method.

=cut

# allow for short names. we map to class->new
my %ashort = (
    fs     => 'SWISH::Prog::Aggregator::FS',
    mail   => 'SWISH::Prog::Aggregator::Mail',
    dbi    => 'SWISH::Prog::Aggregator::DBI',
    spider => 'SWISH::Prog::Aggregator::Spider',
    object => 'SWISH::Prog::Aggregator::Object',
);
my %ishort = (
    native => 'SWISH::Prog::Native::Indexer',
    xapian => 'SWISH::Prog::Xapian::Indexer',
    ks     => 'SWISH::Prog::KSx::Indexer',
    dbi    => 'SWISH::Prog::DBI::Indexer',
);

sub init {
    my $self   = shift;
    my %arg    = @_;
    my $filter = delete $arg{filter};    # no such method. just convenience.
    $self->SUPER::init(%arg);

    # search mode requires only invindex
    if ( $self->{query} && !$self->{indexer} && !$self->{aggregator} ) {
        return;
    }

    # need to make sure we have an aggregator
    # indexer and/or config might already be set in aggregator
    # but if set here, we override.

    my ( $aggregator, $indexer );

    # ok if undef
    my $config = $self->{config};

    # get indexer
    $indexer = $self->{indexer} || 'native';
    if ( $self->{aggregator} and blessed( $self->{aggregator} ) ) {
        $indexer = $self->{aggregator}->indexer;
        $config  = $self->{aggregator}->config;
    }
    if ( !blessed($indexer) ) {

        if ( exists $ishort{$indexer} ) {
            $indexer = $ishort{$indexer};
        }

        $self->debug and warn "creating indexer: $indexer";
        eval "require $indexer";
        if ($@) {
            croak "invalid indexer $indexer: $@";
        }
        $indexer = $indexer->new(
            debug     => $self->debug,
            invindex  => $self->{invindex},    # may be undef
            verbose   => $self->verbose,
            config    => $config,              # may be undef
            test_mode => $self->test_mode,
        );
    }
    elsif ( !$indexer->isa('SWISH::Prog::Indexer') ) {
        croak "$indexer is not a SWISH::Prog::Indexer-derived object";
    }

    $aggregator = $self->{aggregator} || 'fs';

    if ( !blessed($aggregator) ) {

        if ( exists $ashort{$aggregator} ) {
            $aggregator = $ashort{$aggregator};
        }

        $self->debug and warn "creating aggregator: $aggregator";
        eval "require $aggregator";
        if ($@) {
            croak "invalid aggregator $aggregator: $@";
        }
        $aggregator = $aggregator->new(
            indexer   => $indexer,
            debug     => $self->debug,
            verbose   => $self->verbose,
            test_mode => $self->test_mode,
        );
    }
    elsif ( !$aggregator->isa('SWISH::Prog::Aggregator') ) {
        croak "$aggregator is not a SWISH::Prog::Aggregator-derived object";
    }

    if ($filter) {
        $aggregator->set_filter($filter);
    }

    $self->{aggregator} = $aggregator;
    $self->{indexer}    = $indexer;

    $indexer->{test_mode} = $self->{test_mode}
        unless exists $indexer->{test_mode};
    $aggregator->{test_mode} = $self->{test_mode}
        unless exists $aggregator->{test_mode};

    $self->debug and carp dump $self;

    return $self;
}

=head2 aggregator( I<$swish_prog_aggregator> )

Get the SWISH::Prog::Aggregator object. You should set this in new().

=head2 run( I<collection> )

Execute the program. This is an alias for index().

=cut

*run = \&index;

=head2 index( I<collection> )

Add items in I<collection> to the invindex().

=cut

sub index {
    my $self = shift;
    my $aggregator = $self->aggregator or croak 'aggregator required';
    unless ( $aggregator->isa('SWISH::Prog::Aggregator') ) {
        croak "aggregator is not a SWISH::Prog::Aggregator";
    }

    $aggregator->indexer->start;
    $aggregator->crawl(@_);
    $aggregator->indexer->finish;
    return $aggregator->indexer->count;
}

=head2 config

Returns the aggregator's config() object.

=cut

sub config {
    my $self = shift;
    if ( $self->aggregator ) {
        return $self->aggregator->config;
    }
    if ( $self->indexer ) {
        return $self->indexer->config;
    }
    return undef;
}

=head2 invindex

Returns the indexer's invindex.

=cut

sub invindex {
    my $self = shift;
    if ( $self->aggregator ) {
        return $self->indexer->invindex;
    }
    return blessed( $self->{invindex} )
        ? $self->{invindex}
        : SWISH::Prog::InvIndex->new( path => $self->{invindex} );
}

=head2 indexer

Returns the indexer.

=cut

sub indexer {
    shift->aggregator->indexer;
}

=head2 count

Returns the indexer's count. B<NOTE> This is the number of documents
actually indexed, not counting the number of documents considered and
discarded by the aggregator. If you want the number of documents
the aggregator looked at, regardless of whether they were indexed,
use the aggregator's count() method.

=cut

sub count {
    shift->indexer->count;
}

=head2 test_mode

Dry run mode, just prints info on stderr but does not
build index. This flag is set in new() and passed to
the indexer and aggregator.

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

=item * Mailing list

L<http://lists.swish-e.org/listinfo/users>

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

SWISH::Prog::Doc,
SWISH::Prog::Headers,
SWISH::Prog::Indexer,
SWISH::Prog::InvIndex,
SWISH::Prog::Utils,
SWISH::Prog::Aggregator,
SWISH::Prog::Config
