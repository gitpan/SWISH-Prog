package SWISH::Prog;

use 5.8.3;
use strict;
use warnings;
use bytes;

use Carp;
use Data::Dump qw(pp);

use File::Basename;
use File::Slurp;
use LWP::UserAgent;

use MIME::Types;
use SWISH::Filter;

use SWISH::Prog::Config;
use SWISH::Prog::Doc;
use SWISH::Prog::Index;

use base qw( Class::Accessor::Fast );

our $VERSION = '0.05';
our $ExtRE   = qr{(html|htm|xml|txt|pdf|ps|doc|ppt|xls|mp3)(\.gz)?}io;

our %ParserTypes = (

    # mime                  parser type
    'text/html'          => 'HTML*',
    'text/xml'           => 'XML*',
    'application/xml'    => 'XML*',
    'text/plain'         => 'TXT*',
    'application/pdf'    => 'HTML*',
    'application/msword' => 'HTML*',
    'audio/mpeg'         => 'XML*',
    'default'            => 'HTML*',
);

# methods SWISH::Prog::Index also uses
# 0.03 added config here so Index->new inherits it
our @IndexMeth = qw/ name verbose opts warnings exe debug config /;

=pod

=head1 NAME

SWISH::Prog - build Swish-e programs

=head1 SYNOPSIS

  # create a Prog module by subclassing SWISH::Prog and SWISH::Prog::Doc
  package MyProg;
  use base qw( SWISH::Prog );
  
  sub ok
  {
    my $prog = shift;
    my $doc = shift;
    
    # index everything
    1;
  }
  
  1;
  
  package MyProg::Doc;
  use base qw( SWISH::Prog::Doc );
  
  # pass content untouched
  
  1;
  
  # elsewhere:
  use MyProg;
  use Carp;
  
  my $prog = My::Prog->new(
                name    => 'myindex',
                opts    => '-W1 -v0',
                config  => 'some/swish/config/file',
                );
                
  $prog->find('some/dir');
          

=head1 DESCRIPTION

SWISH::Prog is a framework for indexing document collections with Swish-e.
This module is a collection of utility methods for writing your own applications.

B<The API is a work in progress and subject to change.>

=head1 METHODS

All of the following methods may be overridden when subclassing
this module.


=head2 new( %I<opts> )

Instantiate a new SWISH::Prog object. %I<opts> may include:

=over

=item ua

User Agent for fetching remote files. By default this is a 
LWP::UserAgent object with default settings, but you could
pass in your own LWP::UserAgent with your own settings,
or any other user agent that supports the same methods.

=item name

Full path name of the index. Ignored if C<fh> is passed.

=item config

Either a full path name to a Swish-e config file, or a 
SWISH::Prog::Config object. See Swish-e and SWISH::Prog::Config
documentation.

=item fh

A filehandle reference. If set, fh will override any options
related to the swish-e command and instead write all output
to the filehandle.

Example:

 fh => *STDOUT{IO}
 
will write all output to stdout and will not open a pipe
to the swish-e command.

The default filehandle is named C<SWISH> and is tied via a piped
open() to the C<swish-e -S prog -i stdin> command.

If set to 0 or undef, the filehandle will default to STDOUT as
in the example above. Use this feature to cache all output in a file
for later indexing or debugging.

See L<fh()>.

=item debug

Print stuff on stderr.

=item strict

Perform sanity checks on content types for documents retrieved
using User Agent. You might want this if you want to verify the 
content type against the actual content of the file.

=back

You may pass any other key/value pairs you want and deal with them
by overriding init().

You probably don't want to override new(). 
See init() and init_indexer() instead.

=cut

sub new
{
    my $class = shift;
    my $self  = {};
    bless($self, $class);
    $self->_init($class, @_);
    $self->init();
    $self->_init_indexer();
    return $self;
}

# don't override this! use init() or init_indexer() instead.
sub _init
{
    my $self  = shift;
    my $class = shift;

    # make sure we have a Doc class available
    my $docclass = join('::', $class, 'Doc');
    unless ($docclass->can('new'))
    {
        croak "Doc subclass $docclass required for $class";
    }
    $self->{docclass} = $docclass;

    # make methods in $class's namespace
    $class->mk_accessors(
        qw(
          file_typer
          swish_filter
          fh
          ua
          debug
          strict
          indexer
          ),

        @IndexMeth
    );
    $class->mk_ro_accessors(qw( counter docclass ));

    # init params
    $self->{'_start'} = time;
    if (@_)
    {
        my %extra = @_;
        @$self{keys %extra} = values %extra;
    }

    $self->{verbose} = 1 unless defined $self->{verbose};

    $self->{debug} ||= $ENV{PERL_DEBUG} || 0;

    $self->{counter} = 0;

    # cache filter objects
    $self->{swish_filter} ||= SWISH::Filter->new;
    $self->{file_typer}   ||= MIME::Types->new;

    # new user agent for http requests
    $self->{ua} ||= LWP::UserAgent->new;

    # new config unless defined
    $self->{config} ||= SWISH::Prog::Config->new(debug => $self->debug);

    # make sure we've got an object in config()
    unless (ref $self->{config} && $self->{config}->isa('SWISH::Prog::Config'))
    {
        my $f = $self->{config};
        unless (-r $f)
        {
            croak "config file $f is not read-able: $!";
        }
        $self->{config} = SWISH::Prog::Config->new(debug => $self->debug);

        # TODO test for ver2 vs. ver3 style
        $self->{config}->read2($f);
    }

    # make sure debug flag inherits
    $self->config->debug($self->debug) unless defined($self->config->debug);

}

sub _init_indexer
{

    # open pipe to swish-e -S prog
    # and set filehandle accordlingly
    my $self = shift;

    unless (exists $self->{fh})
    {
        $self->init_indexer;
    }
    else
    {
        $self->indexer(SWISH::Prog::Index->new($self));
    }

    # if fh = 0 or undef, default to stdout
    # this is useful for caching output to a file for indexing later
    $self->{fh} ||= *STDOUT{IO};

}

=head2 init

Called within new() after the object is blessed and internal
initialization is done.

This method is designed to be overridden in your subclass.
Only the object is passed. Return value is ignored.

The basic initialization order is:

=over

=item _init()

Private internal method. Blesses object and sets up sane defaults based
on args to new().

=item init()

Public method. Initalize your object beyond the default _init(). The base
init() does nothing.

=item init_indexer

Public method. Sets indexer() and fh(). Override this method in your subclass
to customize config() or anything else that should be done after init() and
before the C<swish-e> index is opened.

=back

=cut

sub init
{
    my $self = shift;

    1;
}

=head2 init_indexer

Creates and caches a SWISH::Prog::Index object in indexer(), and sets fh().
You can override this method if you want to customize the order
of when the index is opened for writing, or want to pass specific
options to the S::P::Index new() method.

=cut

sub init_indexer
{
    my $self = shift;
    $self->indexer(SWISH::Prog::Index->new($self)->run);
    $self->fh($self->indexer->fh);
}

=head2 DESTROY

The default DESTROY method simply calls close() on the fh() value.
If you override this method, you should call 

 $self->SUPER::DESTROY();

as well. See SWISH::Prog::DBI for an example.

=cut

sub DESTROY
{
    my $self = shift;
    if ($self->{fh})
    {
        close($self->{fh})
          or croak "can't close filehandle $self->{fh}: $!\n";
    }
}

# pod only; method created with Class::Accessor

=head2 fh( [ I<filehandle> ] )

Get/set filehandle reference. 

B<CAUTION:> Only do this if you know
what you're doing. The default filehandle is a pipe to the swish-e
indexer and you could botch things royally if you changed that filehandle.

Examples of possible use include printing documents to different
filehandles based on some criteria of your design. You would not need
to override index(), but just change which filehandle index() will
print to. Think of it like Perl's built-in select() function.
You might open multiple swish-e indexers, for example, one
per index, and thus create multiple indexes simultaneously from a single
source. (This author would love to see good examples of doing that!)

=head2 ua( I<user agent> )

By default this is a LWP::UserAgent object. Get/set it to taste.

=head2 config

Get/set SWISH::Prog::Config object.

=head2 strict

Get/set strict flag. See new().

=head2 debug

Get/set debug flag. See new().

=head2 indexer

SWISH::Prog::Index object. Set in init_indexer().


=head2 remote( I<URL> )

Returns true (1) if I<URL> matches a pattern that looks
like a URI scheme (http://, ftp://, etc.). Otherwise,
returns false (0).

B<NOTE:> This will match file:// but LWP::UserAgent should
fetch file:// URLs just like any other URL.

=cut

sub remote { $_[1] =~ m!^[\w]+://!o }

=head2 fetch( I<URL> [, I<stat_ref>, I<file_ext>] )

Retrieve I<URL> either via HTTP or from filesystem.

Returns a Doc object. See SWISH::Prog::Doc documentation
for how to subclass SWISH::Prog::Doc.

=cut

my %ext_to_mime = ();    # cache to avoid hitting MIME::Type each time

sub fetch
{
    my $self = shift;
    my $url  = shift;
    my $stat = shift;
    my $ext  = shift;

    my %doc = ();

    if ($self->remote($url))
    {

        my $response = $self->{ua}->get($url);

        if ($response->is_success)
        {
            %doc = (
                    url     => $url,
                    modtime => $response->last_modified,
                    type    => $response->content_type,
                    content => $response->content,
                    size    => $response->content_length
                   );

        }
        else
        {
            croak $response->status_line;    # can catch with eval()
        }

        if ($self->strict)
        {
            my $mime = $self->file_typer->mimeTypeOf($url);
            if ($mime ne $doc{type})
            {
                carp "Warning: http header says Content-type=$doc{type} "
                  . "but content looks like $mime. "
                  . "We're using $mime";

                $doc{type} = $mime;
            }
        }

    }
    else
    {
        my $buf;
        
        # the parser->slurp is about 30% faster.
        if ($self->can('parser') and $self->parser->isa('SWISH::Parser'))
        {
            eval { $buf = $self->parser->slurp_file($url) };
        }
        else
        {
            eval { $buf = read_file($url, binmode => ':raw') };
        }
        if ($@)
        {
            carp "unable to read $url - skipping";
            return;
        }

        $stat ||= [stat($url)];

        # cache the mime type as a string
        # to avoid the MIME::Type::type() stringification
        my $type;
        if ($ext)
        {
            $ext_to_mime{$ext} ||= $self->file_typer->mimeTypeOf($url) . "";
            $type = $ext_to_mime{$ext};
        }
        else
        {
            $type = $self->file_typer->mimeTypeOf($url) . "";
        }

        %doc = (
                url     => $url,
                modtime => $stat->[9],
                content => $buf,
                type    => $type,
                size    => $stat->[7],
                debug   => $self->debug
               );
    }

    $doc{parser} = $ParserTypes{$doc{type}} || $ParserTypes{default};

    if ($self->swish_filter->can_filter($doc{type}))
    {
        my $f =
          $self->swish_filter->convert(
                                       document     => \$doc{content},
                                       content_type => $doc{type},
                                       name         => $doc{url}
                                      );

        if (   !$f
            || !$f->was_filtered
            || $f->is_binary)    # is is_binary necessary?
        {
            carp "skipping $doc{url} - filtering error";
            return;
        }

        $doc{content} = ${$f->fetch_doc};

        # leave type and parser as-is
        # since we want to store original mime in indexer
        # TODO what about parser ?
        # since type will have changed ( $f->content_type ) from original
        # the parser type might also have changed?

        $doc{parser} = $f->swish_parser_type if $self->strict;

    }

    return $self->docclass->new(%doc);
}

=head2 find( @I<paths> )

Use SWISH::Prog::Find to traverse @I<paths>.

=cut

sub find
{
    require SWISH::Prog::Find;
    SWISH::Prog::Find::files(@_);
}

=head2 spider B<NOT YET IMPLEMENTED>

Returns a SWISH::Prog::Spider object.


=head2 ok( I<doc_object> )

Returns true (1) if I<doc_object> is acceptable for indexing.

The default is simply to call content_ok(). This method
is a prime candidate for overriding in your subclass.

=cut

sub ok
{
    my $self = shift;
    my $doc  = shift or croak "need Doc object";

    return $self->content_ok($doc);
}

=head2 content_ok( I<doc_object> )

Perform tests on I<doc_object> content().

Return false (0)
if any of the tests fails. A test can be anything: a regexp check,
a size check, whatever.

The default test is simply that length() > 0.

=cut

sub content_ok
{
    my $self = shift;
    my $doc  = shift or croak "need Doc object";

    return length($doc->content);
}

=head2 url_ok( I<URL> )

Check I<URL> before fetch()ing it.

Returns 0 if I<URL> should be skipped.

Returns file extension of I<URL> if I<URL> should be processed.

=cut

sub url_ok
{

    # TODO read from $self->config to determine opts to check
    my $self = shift;
    my $url  = shift;
    my $stat = shift;

    $self->debug and print "checking file $url\n";

    my ($file, $path, $ext);

    if ($self->remote($url))
    {

    }
    else
    {

        # TODO build regex from ->config
        ($file, $path, $ext) = fileparse($url, $ExtRE);

        #carp "parsed file: $file\npath: $path\next: $ext";

        $stat ||= [stat($url)];
        return 0 unless -r _;
        return 0 if -d _;
        return 0 if $file =~ m/^\./;
        return 0 unless $ext;
        return 0 if $url =~ m!/(\.svn|RCS)/!;

        $self->debug and print "  $url -> ok\n";

    }

    return $ext;
}

=head2 dir_ok( I<directory> )

Called by find() for all directories. You can control
the recursion into I<directory> via the config() params

 TODO
 
=cut

sub dir_ok
{
    my $self = shift;
    my $dir  = shift;
    my $stat = shift || [stat($dir)];
    return 0 unless -d _;
    return 0 if $dir =~ m!/\.!;
    return 0 if $dir =~ m/^\./;

    1;    # TODO esp RecursionDepth
}

=head2 index( I<doc_object> )

Pass I<doc_object> to the indexer.

Runs filter() and ok(), in that order, before handing to the indexer.
 
=cut

sub index
{
    my $self = shift;
    my $doc  = shift or croak "need Doc object";

    unless ($doc->isa('SWISH::Prog::Doc'))
    {
        croak "$doc is not a SWISH::Prog::Doc object";
    }

    #carp "indexing " . $doc->url;

    $self->filter($doc);
    $self->ok($doc) or return;

    carp pp($doc) if $self->debug;

    print {$self->fh} $doc
      or croak "failed to print to filehandle " . $self->fh . ": $!\n";

    $self->{counter}++;

    1;
}

=head2 filter( I<doc_object> )

Filter I<doc_object> before indexing. filter() is called by index()
just before ok().

Think of filter() as a last-chance global filter opportunity similar to the *_filter()
methods available in SWISH::Prog::Doc. The individual *_filter() methods
are called at the time the I<doc_object> is first created. The filter()
method is called later, just before indexing starts.

=cut

sub filter
{
    my $self = shift;
    my $doc  = shift or croak "need Doc object";

    1;
}

=head2 elapsed

Returns the elapsed time in seconds since object was created.

=cut

sub elapsed
{
    return time() - shift->{_start};
}

# utility used by S::P::I
sub _index_methods { return @IndexMeth }

1;
__END__



=head1 SEE ALSO

L<http://swish-e.org/>

SWISH::Prog::Doc,
SWISH::Prog::Headers,
SWISH::Prog::Index,
SWISH::Prog::Config


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

Many of the API ideas here are gleaned from Bill Moseley's DirTree.pl
and spider.pl scripts in Swish-e 2.x.

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

Thanks to Atomic Learning for sponsoring some of the development of this
module.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 
