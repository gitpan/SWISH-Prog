#!/usr/bin/perl

use SWISH::Prog::Mail;

my $usage  = "$0 maildir\n";
my $maildir = shift(@ARGV) or die $usage;

my $prog = SWISH::Prog::Mail->new(maildir => $maildir, verbose => 1);

$prog->create;

