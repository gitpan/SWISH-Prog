package SWISH::Prog::Aggregator::Spider;
use strict;
use warnings;
use base qw( SWISH::Prog::Aggregator );
use Carp;
use Scalar::Util qw( blessed );
use URI;
use SWISH::Prog::Utils;
use SWISH::Prog::Queue;
use SWISH::Prog::Cache;
use SWISH::Prog::Aggregator::Spider::UA;

__PACKAGE__->mk_accessors(
    qw( use_md5 uri_cache md5_cache queue ua max_depth delay timeout ));

#use LWP::Debug qw(+);

our $VERSION = '0.51';

# TODO make these configurable
my %parser_types = %SWISH::Prog::Utils::ParserTypes;
my $default_ext  = $SWISH::Prog::Utils::ExtRE;
my $utils        = 'SWISH::Prog::Utils';

=pod

=head1 NAME

SWISH::Prog::Aggregator::Spider - web aggregator

=head1 SYNOPSIS

 use SWISH::Prog::Aggregator::Spider;
 my $spider = SWISH::Prog::Aggregator::Spider->new(
        indexer => SWISH::Prog::Indexer->new
 );
 
 $spider->indexer->start;
 $spider->crawl( 'http://swish-e.org/' );
 $spider->indexer->finish;

=head1 DESCRIPTION

SWISH::Prog::Aggregator::Spider is a web crawler similar to
the spider.pl script in the Swish-e 2.4 distribution. Internally,
SWISH::Prog::Aggregator::Spider uses WWW::Mechanize to the hard work.
See SWISH::Prog::Aggregator::Spider::UA.

=head1 METHODS

See SWISH::Prog::Aggregator

=head2 new( I<params> )

All I<params> have their own get/set methods too. They include:

=over

=item use_md5 

Flag as to whether each URI's content should be fingerprinted
and compared. Useful if the same content is available under multiple
URIs and you only want to index it once.

=item uri_cache 

Get/set the SWISH::Prog::Cache-derived object used to track which URIs have
been fetched already.

=item md5_cache 

If use_md5() is true, this SWISH::Prog::cache-derived object tracks
the URI fingerprints.

=item queue 

Get/set the SWISH::Prog::Queue-derived object for tracking which URIs still
need to be fetched.

=item ua 

Get/set the SWISH::Prog::Aggregagor::Spider::UA object.

=item max_depth 

How many levels of links to follow. B<NOTE:> This value describes the number
of links from the first argument passed to I<crawl>.

=item delay

Get/set the number of seconds to wait between making requests. Default is
5 seconds (a very friendly delay).

=item timeout

Get/set the number of seconds to wait before considering the remote
server unresponsive. The default is 10.

=back

=head2 init

Initializes a new spider object. Called by new().

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

    # defaults
    $self->{agent}         ||= 'swish-e http://swish-e.org/';
    $self->{email}         ||= 'swish@user.failed.to.set.email.invalid';
    $self->{max_wait_time} ||= 30;
    $self->{max_size}      ||= 5_000_000;
    $self->{max_depth} = 0 unless defined( $self->{max_depth} );
    $self->{delay}     = 5 unless defined $self->{delay};
    croak "delay must be expressed in seconds" if $self->{delay} =~ m/\D/;

    $self->{queue}     ||= SWISH::Prog::Queue->new;
    $self->{uri_cache} ||= SWISH::Prog::Cache->new;
    $self->{_uri_ok_cache} = SWISH::Prog::Cache->new;
    $self->{_auth_cache}   = SWISH::Prog::Cache->new;  # ALWAYS inmemory cache
    $self->{ua}
        ||= SWISH::Prog::Aggregator::Spider::UA->new( stack_depth => 0 );

    $self->{timeout} = 10 unless defined $self->{timeout};
    $self->{ua}->timeout( $self->{timeout} );

    $self->{_current_depth} = 1;

    if ( $self->{use_md5} ) {
        eval "require Digest::MD5" or croak $@;
        $self->{md5_cache} ||= SWISH::Prog::Cache->new;
    }

    return $self;
}

=head2 uri_ok( I<uri> )

Returns true if I<uri> is acceptable for including in an index.
The 'ok-ness' of the I<uri> is based on it's base, robot rules,
and the spider configuration.

=cut

sub uri_ok {
    my $self = shift;
    my $uri  = shift or croak "URI required";
    my $str  = $uri->canonical->as_string;
    return 0 if $self->{_uri_ok_cache}->has($str);
    $self->{_uri_ok_cache}->add($str);

    #warn "uri_ok: $str\n";

    # check base
    if ( $uri->rel( $self->{_base} ) eq $uri ) {
        return 0;
    }

    my $path = $uri->path;
    my $mime = $utils->mime_type($path);

    if ( !exists $parser_types{$mime} ) {

        #warn "no parser for $mime";
        return 0;
    }

    # TODO
    # check robot rules
    # check regex

    return 1;
}

sub _add_links {
    my ( $self, $parent, @links ) = @_;

    # calc depth
    if ( !$self->{_parent} || $self->{_parent} ne $parent ) {
        $self->{_current_depth}++;
    }

    $self->{_parent} ||= $parent;    # first time.

    for my $l (@links) {
        my $uri = $l->url_abs or next;

        next if $self->uri_cache->has($uri);    # check only once
        $self->uri_cache->add( $uri => $self->{_current_depth} );

        if ( $self->uri_ok($uri) ) {
            $self->queue->put($uri);
        }
    }
}

#=================================================================================
# Do we need to authorize?  If so, ask for password and request again.
# First we try using any cached value
# Then we try using the get_password callback
# Then we ask.

# TODO!!
sub _authorize {
    my ( $response, $server, $uri, $parent, $depth ) = @_;

    delete $server->{last_auth};    # since we know that doesn't work

    if (   $response->header('WWW-Authenticate')
        && $response->header('WWW-Authenticate') =~ /realm="([^"]+)"/i )
    {
        my $realm = $1;
        my $user_pass;

        # Do we have a cached user/pass for this realm?
        unless ( $server->{_request}{auth}{$uri}++ )
        {                           # only each URI only once
            my $key = $uri->canonical->host_port . ':' . $realm;

            if ( $user_pass = $server->{auth_cache}{$key} ) {

                # If we didn't just try it, try again
                unless ( $uri->userinfo && $user_pass eq $uri->userinfo ) {

                    # add the user/pass to the URI
                    $uri->userinfo($user_pass);
                    return process_link( $server, $uri, $parent, $depth );
                }
            }
        }

        # now check for a callback password (if $user_pass not set)
        unless ( $user_pass || $server->{_request}{auth}{callback}++ ) {

            # Check for a callback function
            $user_pass
                = $server->{get_password}
                ->( $uri, $server, $response, $realm )
                if ref $server->{get_password} eq 'CODE';
        }

        # otherwise, prompt (over and over)

        if ( !$user_pass ) {
            $user_pass = get_basic_credentials( $uri, $server, $realm );
        }

        if ($user_pass) {
            $uri->userinfo($user_pass);
            $server->{cur_realm}
                = $realm;    # save so we can cache if it's valid
            my $links = process_link( $server, $uri, $parent, $depth );
            delete $server->{cur_realm};
            return $links;
        }
    }

    return;                  # Give up
}

# TODO
sub _get_basic_credentials {
    my ( $uri, $server, $realm ) = @_;

    # Exists but undefined means don't ask.
    return
        if exists $server->{credential_timeout}
            && !defined $server->{credential_timeout};

    # Exists but undefined means don't ask.

    my $netloc = $uri->canonical->host_port;

    my ( $user, $password );

    eval {
        local $SIG{ALRM} = sub { die "timed out\n" };

        # a zero timeout means don't time out
        alarm( $server->{credential_timeout} ) unless $^O =~ /Win32/i;

        if ( $uri->userinfo ) {
            print STDERR "\nSorry: invalid username/password\n";
            $uri->userinfo(undef);
        }

        print STDERR
            "Need Authentication for $uri at realm '$realm'\n(<Enter> skips)\nUsername: ";
        $user = <STDIN>;
        chomp($user) if $user;
        die "No Username specified\n" unless length $user;

        alarm( $server->{credential_timeout} ) unless $^O =~ /Win32/i;

        print STDERR "Password: ";
        system("stty -echo");
        $password = <STDIN>;
        system("stty echo");
        print STDERR "\n";    # because we disabled echo
        chomp($password);
        alarm(0) unless $^O =~ /Win32/i;
    };

    alarm(0) unless $^O =~ /Win32/i;

    return if $@;

    return join ':', $user, $password;

}

=head2 get_doc

Returns the next URI from the queue() as a SWISH::Prog::Doc object,
or the error message if there was one.

Returns undef if the queue is empty or max_depth() has been reached.

=cut

sub get_doc {
    my $self = shift;

    # return unless we have something in the queue
    return unless $self->queue->size;

    # pop the queue and make it a URI
    my $uri   = $self->queue->get;
    my $depth = $self->uri_cache->get($uri);

    return if $depth > $self->max_depth;

    # get our useragent
    my $ua = $self->ua;

    # figure out our delay between requests
    my $delay = 0;
    if ( $self->{keep_alive_connection} ) {
        $delay = 0;
    }
    elsif ( !$self->{delay} || !$self->{_last_response_time} ) {
        $delay = 0;
    }
    else {
        $delay = $self->{delay} - ( time() - $self->{_last_response_time} );
    }

    warn "get $uri (delay: $delay  depth: $depth)\n" if $self->verbose;

    # fetch the uri, waiting $delay seconds before trying.
    $ua->get( $uri, $delay );

    # flag current time for next delay calc.
    $self->{_last_response_time} = time();

    # add its links to the queue
    $self->_add_links( $uri, $ua->links );

    # return $uri as a Doc object
    my $use_uri = $ua->success ? $ua->uri : $uri;
    my $meta = {
        org_uri => $uri,
        ret_uri => ( $use_uri || $uri ),
        depth   => $depth,
        status  => $ua->status,
        success => $ua->success,
        is_html => $ua->is_html,
        title   => $ua->success
        ? $ua->is_html
                ? $ua->title || "No title: $use_uri"
                : $use_uri
        : "Failed: $use_uri",
        ct => $ua->success ? $ua->ct : "Unknown",
    };

    my $response = $ua->response;
    my $headers  = $response->headers;
    my $buf      = $response->content;

    if ( $self->{use_md5} ) {
        my $fingerprint = $response->header('Content-MD5')
            || Digest::MD5::md5($buf);
        if ( $self->md5_cache->has($fingerprint) ) {
            return "duplicate content for "
                . $self->md5_cache->get($fingerprint);
        }
        $self->md5_cache->add( $fingerprint => $uri );
    }

    if ( $ua->success ) {

        my $content_type = $meta->{ct};
        if ( !exists $parser_types{$content_type} ) {
            warn "no parser for $content_type";
        }
        my $charset = $headers->content_type;
        $charset =~ s/;?$meta->{ct};?//;
        my %doc = (
            url     => $meta->{org_uri},
            modtime => $headers->last_modified || $headers->date,
            type    => $meta->{ct},
            content => $buf,
            size => $headers->content_length || length( pack 'C0a*', $buf ),
            charset => $headers->content_encoding || $charset,
        );
        return $self->doc_class->new(%doc);

    }
    elsif ( $response->code == 401 ) {

        # TODO get auth
        warn $response->status_line;
        return $response->code;

    }
    else {

        warn $response->status_line;
        return $response->code;
    }

    return;    # never get here.
}

=head2 crawl( I<uri> )

Implements the required crawl() method. Recursively fetches I<uri>
and its child links to a depth set in max_depth().

=cut

sub crawl {
    my $self = shift;
    my @urls = @_;

    my $indexer = $self->indexer;

    for my $url (@urls) {
        my $uri = URI->new($url);
        $self->uri_cache->add( $uri => 1 );
        $self->queue->put($uri);
        $self->{_base} = $uri->canonical->as_string;
        while ( my $doc = $self->get_doc ) {
            next unless blessed($doc);
            $indexer->process($doc);
            $self->_increment_count;
        }
    }

    return $self->count;
}

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 BUGS

Please report any bugs or feature requests to C<bug-swish-prog at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SWISH-Prog>.  
I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SWISH::Prog


You can also look for information at:

=over 4

=item * Mailing list

L<http://lists.swish-e.org/listinfo/users>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SWISH-Prog>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SWISH-Prog>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SWISH-Prog>

=item * Search CPAN

L<http://search.cpan.org/dist/SWISH-Prog/>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 SEE ALSO

L<http://swish-e.org/>
