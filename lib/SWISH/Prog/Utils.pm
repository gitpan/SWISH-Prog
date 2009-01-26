package SWISH::Prog::Utils;
use strict;
use warnings;
use Carp;
use Data::Dump qw( dump );
use MIME::Types;
use File::Basename;
use Search::Tools::XML;

our $VERSION = '0.25';

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

our $ExtRE = qr{(html|htm|xml|txt|pdf|ps|doc|ppt|xls|mp3)(\.gz)?}io;
our $XML   = Search::Tools::XML->new;

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

=head2 perl_to_xml( I<ref>, I<root_element> )

Similar to the XML::Simple XMLout() feature, perl_to_xml()
will take a Perl data structure I<ref> and convert it to XML,
using I<root_element> as the top-level element.

=cut

sub perl_to_xml {
    my $self = shift;
    my $perl = shift;
    my $root = shift || '_root';
    unless ( defined $perl ) {
        croak "perl data struct required";
    }

    if ( !ref $perl ) {
        return $XML->start_tag($root)
            . $XML->utf8_safe($perl)
            . $XML->end_tag($root);
    }

    my $xml = $XML->start_tag($root);
    $self->_ref_to_xml( $perl, '', \$xml );
    $xml .= $XML->end_tag($root);
    return $xml;
}

sub _ref_to_xml {
    my ( $self, $perl, $root, $xml_ref ) = @_;
    my $type = ref $perl;
    if ( !$type ) {
        $$xml_ref .= $XML->start_tag($root) if length($root);
        $$xml_ref .= $XML->utf8_safe($perl);
        $$xml_ref .= $XML->end_tag($root)   if length($root);
        $$xml_ref .= "\n";    # just for debugging
    }
    elsif ( $type eq 'SCALAR' ) {
        $self->_scalar_to_xml( $perl, $root, $xml_ref );
    }
    elsif ( $type eq 'ARRAY' ) {
        $self->_array_to_xml( $perl, $root, $xml_ref );
    }
    elsif ( $type eq 'HASH' ) {
        $self->_hash_to_xml( $perl, $root, $xml_ref );
    }
    else {
        croak "unsupported ref type: $type";
    }

}

sub _array_to_xml {
    my ( $self, $perl, $root, $xml_ref ) = @_;
    for my $thing (@$perl) {
        if ( ref $thing and length($root) ) {
            $$xml_ref .= $XML->start_tag($root);
        }
        $self->_ref_to_xml( $thing, $root, $xml_ref );
        if ( ref $thing and length($root) ) {
            $$xml_ref .= $XML->end_tag($root);
        }
    }
}

sub _hash_to_xml {
    my ( $self, $perl, $root, $xml_ref ) = @_;
    for my $key ( keys %$perl ) {
        my $thing = $perl->{$key};
        if ( ref $thing ) {
            $$xml_ref .= $XML->start_tag($key);
            $self->_ref_to_xml( $thing, $key, $xml_ref );
            $$xml_ref .= $XML->end_tag($key);
            $$xml_ref .= "\n";                  # just for debugging
        }
        else {
            $self->_ref_to_xml( $thing, $key, $xml_ref );
        }
    }
}

sub _scalar_to_xml {
    my ( $self, $perl, $root, $xml_ref ) = @_;
    $$xml_ref
        .= $XML->start_tag($root)
        . $XML->utf8_safe($$perl)
        . $XML->end_tag($root);
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
