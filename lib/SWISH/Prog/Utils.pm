package SWISH::Prog::Utils;
use strict;
use warnings;
use Carp;
use Data::Dump qw( dump );
use File::Basename;
use Search::Tools::XML;

our $VERSION = '0.35';

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

=item %ParserTypes

Hash of MIME types to their equivalent parser.

=back

=cut

our $ExtRE
    = qr{\.(html|htm|xml|txt|pdf|ps|doc|ppt|xls|mp3|css|ico|js|php)(\.gz)?}io;
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

# cache to avoid hitting MIME::Type each time
my %ext2mime = (
    doc  => 'application/msword',
    pdf  => 'application/pdf',
    ppt  => 'application/vnd.ms-powerpoint',
    html => 'text/html',
    htm  => 'text/html',
    txt  => 'text/plain',
    text => 'text/plain',
    xml  => 'application/xml',
    mp3  => 'audio/mpeg',
    gz   => 'application/x-gzip',
    xls  => 'application/vnd.ms-excel',
    zip  => 'application/zip',

);

# prime the cache with some typical defaults that MIME::Type won't match.
$ext2mime{'php'} = 'text/html';

eval { require MIME::Types };
my $mime_types;
if ( !$@ ) {
    $mime_types = MIME::Types->new;
}
my $XML = Search::Tools::XML->new;

=head1 METHODS

=head2 mime_type( I<url> [, I<ext> ] )

Returns MIME type for I<url>. If I<ext> is used, that is checked against
MIME::Types. Otherwise the I<url> is parsed for an extension using 
path_parts() and then fed to MIME::Types.

=cut

sub mime_type {
    my $self = shift;
    my $url  = shift or return;
    my $ext  = lc( shift || ( $self->path_parts($url) )[2] );
    $ext =~ s/^\.//;
    $ext ||= 'html';

    #warn "$url => $ext";
    if ( !exists $ext2mime{$ext} and $mime_types ) {

        # cache the mime type as a string
        # to avoid the MIME::Type::type() stringification
        my $mime = $mime_types->mimeTypeOf($url) or return;
        $ext2mime{$ext} = $mime . "";
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

=head2 perl_to_xml( I<ref>, I<root_element> [, I<strip_plural> ] )

Similar to the XML::Simple XMLout() feature, perl_to_xml()
will take a Perl data structure I<ref> and convert it to XML,
using I<root_element> as the top-level element.

If I<strip_plural> is a true value and not a CODE ref, 
any trailing C<s> character will be stripped from the enclosing tag name 
whenever an array of hashrefs is found. Example:

 my $data = {
    values => [
        {   two   => 2,
            three => 3,
        },
        {   four => 4,
            five => 5,
        },
    ],
 };

 my $xml = $utils->perl_to_xml($data, 'data', 1);
 
 # $xml DOM will look like:
 
 <data>
  <values>
   <value>
    <three>3</three>
    <two>2</two>
   </value>
   <value>
    <five>5</five>
    <four>4</four>
   </value>
  </values>
 </data>

Obviously stripping the final C<s> will not always render sensical tag names.
Pass a CODE ref instead, expecting one value (the tag name) and returning the
tag name to use:

 use Lingua::EN::Inflect;
 my $xml = $utils->perl_to_xml($data, 'data', \&Lingua::EN::Inflect::PL);

=cut

sub _make_singular {
    my ($t) = @_;
    $t =~ s/s$//i;
    return length $t ? $t : $_[0];
}

sub perl_to_xml {
    my $self         = shift;
    my $perl         = shift;
    my $root         = shift || '_root';
    my $strip_plural = shift || 0;
    unless ( defined $perl ) {
        croak "perl data struct required";
    }

    if ( $strip_plural and ref($strip_plural) ne 'CODE' ) {
        $strip_plural = \&_make_singular;
    }

    if ( !ref $perl ) {
        return
              $XML->start_tag($root)
            . $XML->utf8_safe($perl)
            . $XML->end_tag($root);
    }

    my $xml = $XML->start_tag($root);
    $self->_ref_to_xml( $perl, '', \$xml, $strip_plural );
    $xml .= $XML->end_tag($root);
    return $xml;
}

sub _ref_to_xml {
    my ( $self, $perl, $root, $xml_ref, $strip_plural ) = @_;
    my $type = ref $perl;
    if ( !$type ) {
        ( $$xml_ref .= $XML->start_tag($root) )
            if length($root);
        $$xml_ref .= $XML->utf8_safe($perl);
        ( $$xml_ref .= $XML->end_tag($root) )
            if length($root);

        #$$xml_ref .= "\n";    # just for debugging
    }
    elsif ( $type eq 'SCALAR' ) {
        $self->_scalar_to_xml( $perl, $root, $xml_ref, $strip_plural );
    }
    elsif ( $type eq 'ARRAY' ) {
        $self->_array_to_xml( $perl, $root, $xml_ref, $strip_plural );
    }
    elsif ( $type eq 'HASH' ) {
        $self->_hash_to_xml( $perl, $root, $xml_ref, $strip_plural );
    }
    else {
        croak "unsupported ref type: $type";
    }

}

sub _array_to_xml {
    my ( $self, $perl, $root, $xml_ref, $strip_plural ) = @_;
    for my $thing (@$perl) {
        if ( ref $thing and length($root) ) {
            $$xml_ref .= $XML->start_tag($root);
        }
        $self->_ref_to_xml( $thing, $root, $xml_ref, $strip_plural );
        if ( ref $thing and length($root) ) {
            $$xml_ref .= $XML->end_tag($root);
        }
    }
}

sub _hash_to_xml {
    my ( $self, $perl, $root, $xml_ref, $strip_plural ) = @_;
    for my $key ( keys %$perl ) {
        my $thing = $perl->{$key};
        if ( ref $thing ) {
            my $key_to_pass = $key;
            my %attr;
            if ( ref $thing eq 'ARRAY' && $strip_plural ) {
                $key_to_pass = $strip_plural->($key_to_pass);
                $attr{count} = scalar @$thing;
            }
            $$xml_ref .= $XML->start_tag( $key, \%attr );
            $self->_ref_to_xml( $thing, $key_to_pass, $xml_ref,
                $strip_plural );
            $$xml_ref .= $XML->end_tag($key);

            #$$xml_ref .= "\n";                  # just for debugging
        }
        else {
            $self->_ref_to_xml( $thing, $key, $xml_ref, $strip_plural );
        }
    }
}

sub _scalar_to_xml {
    my ( $self, $perl, $root, $xml_ref, $strip_plural ) = @_;
    $$xml_ref
        .= $XML->start_tag($root)
        . $XML->utf8_safe($$perl)
        . $XML->end_tag($root);

    #$$xml_ref .= "\n";    # just for debugging
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
