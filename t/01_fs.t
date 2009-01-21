use Test::More tests => 10;

use_ok('SWISH::Prog');
use_ok('SWISH::Prog::Indexer::Native');
use_ok('SWISH::Prog::Aggregator::FS');
use_ok('SWISH::Prog::Config');

SKIP: {

    # is executable present?
    my $test = SWISH::Prog::Indexer::Native->new;
    if ( !$test->swish_check ) {
        skip "swish-e not installed", 6;
    }

    ok( my $invindex
            = SWISH::Prog::InvIndex::Native->new( path => 't/testindex', ),
        "new invindex"
    );

    ok( my $indexer
            = SWISH::Prog::Indexer::Native->new( invindex => $invindex, ),
        "new indexer"
    );

    ok( my $aggregator = SWISH::Prog::Aggregator::FS->new(
            indexer => $indexer,
            config  => SWISH::Prog::Config->new,
        ),
        "new filesystem aggregator"
    );

    ok( my $prog
            = SWISH::Prog->new( aggregator => $aggregator, verbose => 1 ),
        "new program"
    );

    ok( $prog->run('t/'), "run program" );

    is( $prog->count, 6, "indexed test docs" );

}
