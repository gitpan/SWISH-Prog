use Test::More tests => 1;

use SWISH::Prog::Config;

my $config = SWISH::Prog::Config->new;

$config->metanames(qw/ foo bar baz /);
$config->AbsoluteLinks('yes');
$config->FileInfoCompression(1);

ok(my $file = $config->write2, "temp config written");
#diag($file);
#my $wait = <>;
#diag(`cat $file`);
