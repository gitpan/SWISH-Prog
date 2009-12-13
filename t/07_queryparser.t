use strict;
use warnings;
use Test::More tests => 77;

binmode Test::More->builder->output,         ":utf8";
binmode Test::More->builder->failure_output, ":utf8";
use_ok('SWISH::Prog::QueryParser');
use_ok('SWISH::Prog::Config');
use Search::Tools::UTF8;

my %str = (

    'foo bar'                            => '',
    'bar or foo'                         => '',
    '"foo bar"~10'                       => '',
    'foo not bar'                        => '',
    'swishtitle:foo or swishdefault=bar' => '',
    '(foo AND bar) or quz'               => '',
    'adobe -photoshop'                   => '',
    'latin=Ärzte'                        => 'latin=Ã„rzte',

);

ok( my $parser = SWISH::Prog::QueryParser->new(
        config => SWISH::Prog::Config->new(),
        locale => 'en_US.iso-8859-1',
    ),
    "parser"
);

diag('');    # just for the newline
for my $s ( sort keys %str ) {
    my $v = to_utf8( $str{$s} || $s );
    if ( $s =~ m/latin/ ) {
        isnt( $s, $str{$s}, "hash key/value encoding mismatch" );
        is( $s, $v, "hash key/value encoding fixed" );
    }

    #diag($s);
    #diag($v);
    #Search::Tools::describe($s);
    #Search::Tools::describe($v);

    ok( is_latin1($s),        "\$s $s is latin1" );
    ok( !is_flagged_utf8($s), "\$s $s is not flagged utf8" );
    ok( is_valid_utf8($v),    "\$v $v is valid utf8" );
    ok( is_flagged_utf8($v),  "\$v $v is flagged utf8" );
    my $q = $parser->parse($s);
    diag( sprintf( "%40s  ->  %s [%s]", $s, $q, $v ) );
    is( "$q", $v, "stringified: $q" );
    ok( is_valid_utf8("$q"),   "\$q $q is utf8" );
    ok( is_flagged_utf8("$q"), "\$q $q is flagged utf8" );
    ok( !is_flagged_utf8($s),  "\$s $s is still not flagged utf8" );
    ok( is_sane_utf8("$q"),    "\$q $q is sane utf8" );

    #diag( $q->dump );

}

