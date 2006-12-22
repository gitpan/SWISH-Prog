package foo;
our @ISA = 'Class::Accessor::Fast';    # loaded by SWISH::Prog

use Test::More tests => 13;

use SWISH::Prog::Object;

my @meth = qw( one two three );
my @obj;
__PACKAGE__->mk_accessors(@meth);
for (1 .. 10)
{
    ok(
        push(
             @obj,
             bless(
                   {one => $_ + 1, two => [$_ + 2], three => {sum => $_ + 3}},
                   __PACKAGE__
                  )
            ),
        "object blessed"
      );
}

ok(
    my $indexer = SWISH::Prog::Object->new(
        class   => __PACKAGE__,
        methods => [@meth],
        title   => 'one',
        name    => 'swishobjects',
        #debug   => 1,
        #verbose => 3,
        #warnings => 9,
        #opts => '-T indexed_words'
                                          ),
    "indexer"
  );

ok(my $count = $indexer->create(\@obj), "create()");

ok($count == 10, "10 objects indexed");
