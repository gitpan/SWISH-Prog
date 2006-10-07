use Test::More tests => 3;
use SWISH::Prog;

# add doc object to index
ok(my $i = SWISH::Prog->new(fh=>0), "index.swish-e");
ok(my $doc = $i->fetch('t/test2.html'),      "doc object");
ok($i->indexer->add($doc), "add");
