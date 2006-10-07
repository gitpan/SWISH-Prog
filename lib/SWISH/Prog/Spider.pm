package SWISH::Prog::Spider;

use strict;
use warnings;

use Carp;
use Data::Dump qw/dump/;

our $VERSION = '0.01';

1;
__END__

=pod

=head1 NAME

SWISH::Prog::Spider - crawl a website with an iterator

=head1 SYNOPSIS

    use SWISH::Prog;
    my $indexer = SWISH::Prog->new;
    my $spider  = $indexer->spider(
                        'root'   => 'http://swish-e.org/',
                        'config' => \%spider_config
                        
                        );
    # $spider is a SWISH::Prog::Spider object
    
    until($spider->done)
    {
        my $doc = $indexer->fetch($spider->next);
        $indexer->index( $doc ) if $indexer->ok( $doc );
    }


=head1 DESCRIPTION

SWISH::Prog::Spider crawls a website using an iterator.

B<THIS MODULE IS NOT YET IMPLEMENTED.>

=head1 METHODS

=head2 new( I<args> )

 # TODO
 
=head1 REQUIREMENTS

 # TODO

=head1 SEE ALSO

L<http://swish-e.org/docs/>

L<SWISH::Prog>,


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
