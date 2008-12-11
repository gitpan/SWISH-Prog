package SWISH::Prog;

use 5.008_003;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;
use Data::Dump qw( dump );
use Scalar::Util qw( blessed );
use SWISH::Prog::Config;

our $VERSION = '0.23';

__PACKAGE__->mk_accessors(qw( aggregator ));

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
    native => 'SWISH::Prog::Indexer::Native',
    xapian => 'SWISH::Prog::Indexer::Xapian',
    ks     => 'SWISH::Prog::Indexer::KinoSearch',
    dbi    => 'SWISH::Prog::Indexer::DBI',
);

sub init {
    my $self = shift;

    # need to make sure we have 3 items:
    # aggregator
    # indexer
    # config
    # indexer and/or config might already be set in aggregator
    # but if set here, we override.

    my ( $aggregator, $indexer, $config );

    $indexer = $self->{indexer} || 'native';
    if ( !blessed($indexer) ) {

        if ( exists $ishort{$indexer} ) {
            $indexer = $ishort{$indexer};
        }

        eval "require $indexer";
        if ($@) {
            croak "invalid indexer $indexer: $@";
        }
        $indexer = $indexer->new(
            debug    => $self->debug,
            invindex => $self->{invindex},
            verbose  => $self->verbose
        );
    }
    elsif ( !$indexer->isa('SWISH::Prog::Indexer') ) {
        croak "$indexer is not a SWISH::Prog::Indexer-derived object";
    }

    $config = $self->{config} || SWISH::Prog::Config->new(
        debug   => $self->debug,
        verbose => $self->verbose
    );
    if ( !blessed($config) ) {

        unless ( -r $config ) {
            croak "config file $config is not read-able: $!";
        }

        # TODO test for ver2 vs. ver3 style in config
        $config = SWISH::Prog::Config->new(
            debug   => $self->debug,
            file    => $config,
            verbose => $self->verbose
        );
    }
    elsif ( !$config->isa('SWISH::Prog::Config') ) {
        croak "$config is not a SWISH::Prog::Config-derived object";
    }

    $aggregator = $self->{aggregator} || 'fs';
    if ( !blessed($aggregator) ) {

        if ( exists $ashort{$aggregator} ) {
            $aggregator = $ashort{$aggregator};
        }

        eval "require $aggregator";
        if ($@) {
            croak "invalid aggregator $aggregator: $@";
        }
        $aggregator = $aggregator->new(
            indexer => $indexer,
            config  => $config,
            debug   => $self->debug,
            verbose => $self->verbose
        );
    }
    elsif ( !$aggregator->isa('SWISH::Prog::Aggregator') ) {
        croak "$aggregator is not a SWISH::Prog::Aggregator-derived object";
    }

    if ( $self->{filter} ) {
        $aggregator->set_filter( delete $self->{filter} );
    }

    $self->{aggregator} = $aggregator;
}

=head2 run

Execute the program.

=cut

sub run {
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
    shift->aggregator->config;
}

=head2 invindex

Returns the indexer's invindex.

=cut

sub invindex {
    shift->indexer->invindex;
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

1;
__END__



=head1 SEE ALSO

L<http://swish-e.org/>

SWISH::Prog::Doc,
SWISH::Prog::Headers,
SWISH::Prog::Indexer,
SWISH::Prog::InvIndex,
SWISH::Prog::Utils,
SWISH::Prog::Aggregator,
SWISH::Prog::Config


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 
