use Test::More tests => 15;

use_ok('SWISH::Prog::Native::Indexer');

SKIP: {

    eval "use SWISH::Prog::Aggregator::Object";
    if ($@) {
        skip "YAML::Syck required for Object test", 14;
    }

    my @meth = qw( one two three );
    {

        package foo;
        use base 'SWISH::Prog::Class';
        __PACKAGE__->mk_accessors(@meth);
    }

    # is executable present?
    my $indexer = SWISH::Prog::Native::Indexer->new;
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
            indexer => SWISH::Prog::Native::Indexer->new(

                #debug    => 1,
                #verbose  => 3,
                invindex => 't/object.index',
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

    # clean up header so other test counts work
    unlink('t/object.index/swish.xml') unless $ENV{PERL_DEBUG};

}
