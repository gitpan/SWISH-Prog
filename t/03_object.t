use Test::More tests => 15;

use_ok('SWISH::Prog::Indexer::Native');

SKIP: {

    eval "use SWISH::Prog::Aggregator::Object";
    if ( $@ ) {
        skip "YAML::Syck required for Object test", 15;
    }

    my @meth = qw( one two three );
    {

        package foo;
        use base 'SWISH::Prog::Class';
        __PACKAGE__->mk_accessors(@meth);
    }

    # is executable present?
    my $indexer = SWISH::Prog::Indexer::Native->new;
    if ( !$indexer->swish_check ) {
        skip "swish-e not installed", 14;
    }

    # make objects
    my @obj;
    for ( 1 .. 10 ) {
        ok( push(
                @obj,
                bless(
                    {   one   => $_ + 1,
                        two   => [ $_ + 2 ],
                        three => { sum => $_ + 3 }
                    },
                    'foo'
                )
            ),
            "object blessed"
        );
    }

    # create prog parts
    ok( my $aggregator = SWISH::Prog::Aggregator::Object->new(
            class   => 'foo',
            methods => [@meth],
            title   => 'one',
            name    => 'swishobjects',
            indexer => SWISH::Prog::Indexer::Native->new(

                #debug    => 1,
                #verbose  => 3,
                warnings => 9,

                #opts     => '-T indexed_words'
            ),
        ),
        "make indexer"
    );

    #diag( $aggregator->dump );

    ok( $aggregator->indexer->start, "indexer start" );
    is( $aggregator->crawl( \@obj ), 10, "crawl" );
    ok( $aggregator->indexer->finish, "indexer finish" );

}
