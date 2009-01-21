use Test::More tests => 3;

SKIP: {

    if ( !$ENV{TEST_SPIDER} ) {
        skip "set TEST_SPIDER env var to test the spider", 3;
    }

    eval "use SWISH::Prog::Aggregator::Spider";
    if ( $@ && $@ =~ m/WWW::Mechanize/ ) {
        skip "WWW::Mechanize required for spider test", 3;
    }

    use_ok('SWISH::Prog::Indexer::Native');

    # is executable present?
    my $indexer = SWISH::Prog::Indexer::Native->new;
    if ( !$indexer->swish_check ) {
        skip "swish-e not installed", 2;
    }

    ok( my $spider = SWISH::Prog::Aggregator::Spider->new(
            indexer   => SWISH::Prog::Indexer::Native->new,
            verbose   => $ENV{PERL_DEBUG},
            max_depth => 2,
            delay     => 1,
            filter    => sub { diag( "doc filter on " . $_[0]->url ) },
        ),
        "new spider"
    );

    diag("spidering swish-e.org/docs");
    is( $spider->crawl('http://www.swish-e.org/docs/'), 30, "crawl" );

}
