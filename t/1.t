# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
BEGIN { use_ok('SWISH::Prog') }

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use File::Find;

my @files;
my @paths = qw( t );            # just the test directory
my $prog  = SWISH::Prog->new;
my $cnt   = 0;

find(
    {
     wanted => sub {

        #warn '-' x 50 . "\n";
        #warn "file: $_\n";
        #warn "name: $File::Find::name\n";
        if ($prog->url_ok($File::Find::name))
        {
            push(@files, $prog->fetch($File::Find::name));
            $cnt++;
        }
     },
     no_chdir => 1,
    },
    @paths
    );

for my $u (@files)
{
    #diag("indexing $u");
    $prog->index($u);
}

ok($cnt == scalar(@files), "$cnt files indexed");
