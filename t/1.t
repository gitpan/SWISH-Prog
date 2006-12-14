use Test::More tests => 2;
BEGIN { use_ok('SWISH::Prog') }

my $prog  = SWISH::Prog->new;
my $cnt   = 0;

$prog->find('t');

$cnt = $prog->counter;

ok($cnt, "$cnt files indexed");
