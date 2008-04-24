package SWISH::Prog::Utils;
use strict;
use warnings;
use Carp;
use Data::Dump qw( dump );
use MIME::Types;
use File::Basename;
use Search::Tools::XML;

=pod

=head1 NAME

SWISH::Prog::Utils - utility variables and methods

=head1 SYNOPSIS

 use SWISH::Prog::Utils;
 
 # use the utils
 
=head1 DESCRIPTION

This class provides commonly used variables and methods
shared by many classes in the SWISH::Prog project.

=head1 VARIABLES

=over

=item $ExtRE

Regular expression of common file type extensions.

=item $XML

Instance of Search::Tools::XML.

=item %ParserTypes

Hash of MIME types to their equivalent parser.

=back

=cut

our $VERSION = '0.20';
our $ExtRE   = qr{(html|htm|xml|txt|pdf|ps|doc|ppt|xls|mp3)(\.gz)?}io;
our $XML     = Search::Tools::XML->new;

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

my %ext2mime = ();    # cache to avoid hitting MIME::Type each time
my $mime_types = MIME::Types->new;

=head1 METHODS

=head2 mime_type( I<url> [, I<ext> ] )

Returns MIME type for I<url>. If I<ext> is used, that is checked against
MIME::Types. Otherwise the I<url> is parsed for an extension using 
path_parts() and then fed to MIME::Types.

=cut

sub mime_type {
    my $self = shift;
    my $url  = shift or return;
    my $ext  = shift || ( $self->path_parts($url) )[2];
    if ( !exists $ext2mime{$ext} ) {

        # cache the mime type as a string
        # to avoid the MIME::Type::type() stringification

        $ext2mime{$ext} = $mime_types->mimeTypeOf($url) . "";
    }
    return $ext2mime{$ext};
}

=head2 path_parts( I<url> [, I<regex> ] )

Returns array of I<path>, I<file> and I<extension> using the
File::Basename module. If I<regex> is missing or false,
uses $ExtRE.

=cut

sub path_parts {
    my $self = shift;
    my $url  = shift;
    my $re   = shift || $ExtRE;

    # TODO build regex from ->config
    my ( $file, $path, $ext ) = fileparse( $url, $re );
    return ( $path, $file, $ext );
}

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
