package SWISH::Prog::Headers;

use 5.8.0;
use strict;
use warnings;
use Carp;

use bytes;

our $VERSION = '0.08';

# NOTE this does not work.
# instead we require perl > 5.8 and just use bytes straight up.
# see http://www.perlmonks.org/?node=405917
#BEGIN
#{
#
#    # this hack allows us to "use bytes" or fake it for older (pre-5.6.1)
#    # versions of Perl (thanks to Liz from PerlMonks):
#    eval { use bytes };    # treat buffer length as bytes not characters
#
#    if ($@)
#    {
#        warn "could not load bytes pragma\n";
#
#        # couldn't find it, but pretend we did anyway:
#        $INC{'bytes.pm'} = 1;
#
#        # 5.005_03 doesn't inherit UNIVERSAL::unimport:
#        eval "sub bytes::unimport { return 1 }";
#    }
#}

our $AutoURL = $^T;
our $Debug   = $ENV{SWISH3_DEBUG} || 0;

our %Headers = (
    2 => {
          url     => 'Path-Name',
          modtime => 'Last-Mtime',
          parser  => 'Document-Type',
          update  => 'Update-Mode',
         },
    P => {
          url     => 'Content-Location',
          modtime => 'Last-Modified',      # but in epoch seconds
          parser  => 'Parser-Type',
          type    => 'Content-Type',
          update  => 'Update-Mode',
          mime    => 'Content-Type',
         }

);

sub head
{
    my $class   = shift;
    my $buf     = shift || croak "need buffer to generate headers\n";
    my $opts    = shift || {};
    my $version = ($opts->{swish3} || $ENV{SWISH3}) ? 'P' : 2;

    $opts->{url} = $AutoURL++ unless exists $opts->{url};
    $opts->{modtime} ||= time();

    my $size = length($buf);    #length in bytes, not chars

    #    if ($Debug > 2)
    #    {
    #        carp "length = $size";
    #        {
    #            no bytes;
    #            carp "num chars = " . length($buf);
    #            if ($Debug > 20)
    #            {
    #                my $c = 0;
    #                for (split(//, $buf))
    #                {
    #                    carp ++$c . "  $_   = " . ord($_);
    #                }
    #            }
    #        }
    #    }

    my @h = ("Content-Length: $size");

    for my $k (sort keys %$opts)
    {
        next unless defined $opts->{$k};
        my $label = $Headers{$version}->{$k} or next;
        push(@h, "$label: $opts->{$k}");
    }

    return join("\n", @h) . "\n\n";    # extra \n required
}

1;
__END__


=pod

=head1 NAME

SWISH::Prog::Headers - create document headers for Swish-e -S prog

=head1 SYNOPSIS

  use SWISH::Prog::Headers;
  use File::Slurp;
  my $f = 'some/file.html';
  my $buf = read_file( $f ):
  
  print SWISH::Prog::Headers->head( $buf, { url=>$f } ), $buf;

=head1 DESCRIPTION

SWISH::Prog::Headers generates the correct headers
for feeding documents to the Swish-e indexer.

=head1 VARIABLES

=head2 $AutoURL

The $AutoURL package variable is used when no URL is supplied
in the head() method. It is incremented
each time it is used in head(). You can set it to whatever
numerical value you choose. It defaults to $^T.

=head2 $Debug

Set to TRUE to carp verbage about content length, etc.

=head1 METHODS

There is one class method available.

=head2 head( I<buf> [, \%I<opts> ] )

Returns scalar string of proper headers for a document.

The only required parameter is I<buf>, which should be
the content of the document as a scalar string.

The following keys are supported in %I<opts>. If not
supplied, they will be guessed at based on the contents
of I<buf>.

=over

=item url

The URL or file path of the document. If not supplied, a guaranteed unique numeric
value will be used, based on the start time of the calling script.

=item modtime

The last modified time of the document in epoch seconds (time() format).
If not supplied, the current time() value is used.

=item parser

The parser type to be used for the document. If not supplied, it will not
be included in the header and Swish-e will determine the parser type. See
the Swish-e configuration documentation on determining parser type. See also
the SWISH::Prog parser() method.

=item type

The MIME type of the document. If not supplied, it will be guessed at based
on the file extension of the URL (if supplied) or $DefMime. B<NOTE>: MIME type
is only used in SWISH::Parser headers.

=item update

If Swish-e is in incremental mode (which must be indicated by setting the
increm parameter in new()), this value can be used to set the update
mode for the document.

=item swish3

Set to TRUE to use SWISH::3::Parser header labels (including Content-Type).

=back

B<NOTE:> The special environment variable C<SWISH3> is checked in order to 
determine the correct header labels. If you are using SWISH::Parser,
you must set that environment variable, or pass the C<swish3> option.

=head1 Headers API

See the Swish-e documentation at L<http://swish-e.org/>.

For SWISH::3::Parser Headers API (which is slightly different) see
L<http://dev.swish-e.org/wiki/swish3/>.
 
=head1 SEE ALSO

SWISH::Prog,
SWISH::3


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
