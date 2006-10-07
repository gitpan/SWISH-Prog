use Test::More tests => 3;
use SWISH::Prog::Index;

# merge two indexes from first 2 tests
ok(my $i = SWISH::Prog::Index->new(name => 'testindex'), "testindex");
ok(my $n = SWISH::Prog::Index->new, "index.swish-e");
ok($i->merge($n), "merge");
