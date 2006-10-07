#!perl -T

use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage"
  if $@;

plan tests => 10;

# we want to customize S::P::Config so need to specify each mod
#all_pod_coverage_ok();

pod_coverage_ok('SWISH::Prog');
pod_coverage_ok('SWISH::Prog::Doc');
pod_coverage_ok('SWISH::Prog::Find');
pod_coverage_ok('SWISH::Prog::Index');
pod_coverage_ok('SWISH::Prog::Config', {trustme => [qr/^(get|set)$/]});
pod_coverage_ok('SWISH::Prog::DBI');
pod_coverage_ok('SWISH::Prog::DBI::Doc');
pod_coverage_ok('SWISH::Prog::Object');
pod_coverage_ok('SWISH::Prog::Object::Doc');
pod_coverage_ok('SWISH::Prog::Spider');
