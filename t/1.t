use Test::More tests => 2;
BEGIN { use_ok('SWISH::Prog') }

my $prog  = SWISH::Prog->new;
my $cnt   = 0;

my $finder = $prog->find('t');

until ($finder->done)
{
    my $f = $finder->next->stringify;
    if ($prog->url_ok($f))
    {
        $prog->index($prog->fetch($f));
    }
}

$cnt = $prog->counter;

ok($cnt, "$cnt files indexed");
