package SWISH::Prog::Headers;

use 5.008_003;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;
__PACKAGE__->mk_accessors(qw( version ));
use bytes;    # so length() measures bytes

our $VERSION = '0.24';
our $AutoURL = time();
our %Headers = (
    2 => {
        url     => 'Path-Name',
        modtime => 'Last-Mtime',
        parser  => 'Document-Type',
        action  => 'Update-Mode',
    },
    3 => {
        url     => 'Content-Location',
        modtime => 'Last-Modified',      # but in epoch seconds
        parser  => 'Parser-Type',
        type    => 'Content-Type',
        action  => 'Action',
        mime    => 'Content-Type',
        }

);

sub init {
    my $self = shift;
    $self->{version} ||= 2;
    if ($ENV{SWISH3}) {
        $self->{version} = 3;
    }
}

sub head {
    my $self = shift;
    my $buf  = shift;
    $buf = '' unless defined $buf;
    my $opts = shift || {};

    my $version = delete( $opts->{version} ) || $self->version || '2';

    $opts->{url} = $AutoURL++ unless exists $opts->{url};
    $opts->{modtime} ||= time();

    my $size = length($buf);    #length in bytes, not chars

    if ( $self->debug > 2 ) {
        warn "length = $size\n";
        {
            no bytes;
            warn "num chars = " . length($buf) . "\n";
            if ( $self->debug > 20 ) {
                my $c = 0;
                for ( split( //, $buf ) ) {
                    warn ++$c . "  $_   = " . ord($_) . "\n";
                }
            }
        }
    }

    my @h = ("Content-Length: $size");

    for my $k ( sort keys %$opts ) {
        next unless defined $opts->{$k};
        my $label = $Headers{$version}->{$k} or next;

        # TODO map action to version 2 values

        push( @h, "$label: $opts->{$k}" );
    }

    return join( "\n", @h ) . "\n\n";    # extra \n required
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
  my $headers = SWISH::Prog::Headers->new;
  print $headers->head( $buf, { url=>$f } ), $buf;

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

=head2 new

Returns a new object.

=head2 init

Called by new().

=head2 version

Get/set the API version. Default is C<2>.

=head2 head( I<buf> [, \%I<opts> ] )

Returns scalar string of proper headers for a document.

The only required parameter is I<buf>, which should be
the content of the document as a scalar string.

The following keys are supported in %I<opts>. If not
supplied, they will be guessed at based on the contents
of I<buf>.

=over

=item version

Which version of the headers to use. The possible values are
C<2> for Swish-e version 2.x or C<3> for Swish3.

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

=item action

Should the doc be added to, updated in or deleted from the index. 
The url value is used as the unique identifier of the document in the index.
The possible values are:

=over

=item add (default)

If a document with the same url value already
exists, a fatal error is thrown. 

=item update

If a document with the same url does not already exist in the index,
a fatal error is thrown.

=item add_or_update

Check first if url exists in the index, and then add or update as appropriate.
Since this requires additional processing overhead for every document,
it is not the default. It is, however, the safest action to take.

=item delete

Remove the document from the index. If url does not exist, a fatal error
is thrown.

=back

=back

B<NOTE:> The special environment variable C<SWISH3> is checked in order to 
determine the correct header labels. If you are using SWISH::Parser,
you must set that environment variable, or indicate the version with
the C<version> option.

=head1 Headers API

See the Swish-e documentation at L<http://swish-e.org/>.

For SWISH::3::Parser Headers API (which is slightly different) see
L<http://dev.swish-e.org/wiki/swish3/>.
 
=head1 SEE ALSO

SWISH::Prog, SWISH::3


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
