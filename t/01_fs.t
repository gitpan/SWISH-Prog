use Test::More tests => 10;

use_ok('SWISH::Prog');
use_ok('SWISH::Prog::Native::Indexer');
use_ok('SWISH::Prog::Aggregator::FS');
use_ok('SWISH::Prog::Config');

SKIP: {

    # is executable present?
    my $test = SWISH::Prog::Native::Indexer->new;
    if ( !$test->swish_check ) {
        skip "swish-e not installed", 6;
    }

    ok( my $invindex
            = SWISH::Prog::Native::InvIndex->new( path => 't/testindex', ),
        "new invindex"
    );

    ok( my $indexer
            = SWISH::Prog::Native::Indexer->new( invindex => $invindex, ),
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

    # clean up header so other test counts work
    unlink('t/testindex/swish.xml') unless $ENV{PERL_DEBUG};

}
