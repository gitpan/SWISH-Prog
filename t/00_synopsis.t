use Test::More tests => 5;

use_ok('SWISH::Prog');

SKIP: {
    use_ok('SWISH::Prog::Indexer::Native');

    # is executable present?
    my $indexer = SWISH::Prog::Indexer::Native->new;
    if ( !$indexer->swish_check ) {
        skip "swish-e not installed", 4;
    }

    ok( my $program = SWISH::Prog->new(
            invindex   => 't/testindex',
            aggregator => 'fs',
            indexer    => 'native',
            config     => 't/test.conf',
            filter     => sub { diag( "doc filter on " . $_[0]->url ) },
        )
    );

    ok( $program->run('t/'), "run program" );

    is( $program->count, 5, "indexed test docs" );

}
