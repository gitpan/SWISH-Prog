package MyApp::Prog;
use base qw( SWISH::Prog );

sub ok
{
    my $prog = shift;
    my $doc  = shift;

    # index everything
    1;
}

1;

package MyApp::Prog::Doc;
use base qw( SWISH::Prog::Doc );

1;

package main;

use Carp;
use Test::More tests => 1;

my $prog = MyApp::Prog->new(name => 'testindex');

my @list_to_index = qw( t/test.html );

for my $url (@list_to_index)
{
    if ($prog->url_ok($url))
    {
        if (my $doc = $prog->fetch($url))
        {
            ok( $prog->index($doc),     "$url indexed");
        }
        else
        {
            carp "skipping $url";
        }
    }
}
