# This test is nearly identical to 04_mail.t except
# that we don't create 'new' 'tmp' and 'cur'
# subdirs to mimic the maildir format
# and instead just assume every file in a tree
# is one email message.

use strict;
use warnings;
use Test::More tests => 5;
use Path::Class::Dir;

use_ok('SWISH::Prog::Native::Indexer');

SKIP: {

    eval "use SWISH::Prog::Aggregator::MailFS";
    if ($@) {
        diag "install Mail::Box to test MailFS aggregator";
        skip "mail test requires Mail::Box", 4;
    }

    # is executable present?
    my $indexer
        = SWISH::Prog::Native::Indexer->new( 'invindex' => 't/mail.index' );
    if ( !$indexer->swish_check ) {
        skip "swish-e not installed", 4;
    }

    ok( my $mail = SWISH::Prog::Aggregator::MailFS->new(
            indexer => $indexer,
            verbose => $ENV{PERL_DEBUG},
        ),
        "new mail aggregator"
    );

    ok( $mail->indexer->start, "start" );
    is( $mail->crawl('t/mailfs'), 1, "crawl" );
    ok( $mail->indexer->finish, "finish" );

}
