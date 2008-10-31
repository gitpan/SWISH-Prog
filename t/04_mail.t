use Test::More tests => 5;

use_ok('SWISH::Prog::Indexer::Native');

SKIP: {

    eval "use SWISH::Prog::Aggregator::Mail";
    if ($@) {
        skip "mail test requires Mail::Box", 4;
    }

    # is executable present?
    my $indexer = SWISH::Prog::Indexer::Native->new;
    if ( !$indexer->swish_check ) {
        skip "swish-e not installed", 4;
    }

    #maildir requires these dirs but makemaker won't package them
    mkdir('t/maildir/cur');
    mkdir('t/maildir/tmp');
    mkdir('t/maildir/new');

    ok( my $mail = SWISH::Prog::Aggregator::Mail->new(
            indexer => SWISH::Prog::Indexer::Native->new(),
            verbose => $ENV{PERL_DEBUG},
        ),
        "new mail aggregator"
    );

    ok( $mail->indexer->start, "start" );
    is( $mail->crawl('t/maildir'), 1, "crawl" );
    ok( $mail->indexer->finish, "finish" );

}
