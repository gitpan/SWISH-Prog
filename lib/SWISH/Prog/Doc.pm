package SWISH::Prog::Doc;

use strict;
use warnings;
use Carp;
use base qw( SWISH::Prog::Class );

use POSIX qw(locale_h);
use locale;

use overload(
    '""'     => \&as_string,
    fallback => 1,
);

use SWISH::Prog::Headers;

our $VERSION = '0.24';

my @Attr = qw( url modtime type parser content action size charset data );
__PACKAGE__->mk_accessors(@Attr);
my $locale = setlocale(LC_CTYPE);
my ( $lang, $charset ) = split( m/\./, $locale );
$charset ||= 'iso-8859-1';

=pod

=head1 NAME

SWISH::Prog::Doc - Document object class for passing to SWISH::Prog::Indexer

=head1 SYNOPSIS

  # subclass SWISH::Prog::Doc
  # and override filter() method
  
  package MyDoc;
  use base qw( SWISH::Prog::Doc );
  
  sub filter {
    my $doc = shift;
    
    # alter url
    my $url = $doc->url;
    $url =~ s/my.foo.com/my.bar.org/;
    $doc->url( $url );
    
    # alter content
    my $buf = $doc->content;
    $buf =~ s/foo/bar/gi;
    $doc->content( $buf );
  }
  
  1;

=head1 DESCRIPTION

SWISH::Prog::Doc is the base class for Doc objects in the SWISH::Prog
framework. Doc objects are created by SWISH::Prog::Aggregator classes
and processed by SWISH::Prog::Indexer classes.

You can subclass SWISH::Prog::Doc and add a filter() method to alter
the values of the Doc object before it is indexed.

=head1 METHODS

All of the following methods may be overridden when subclassing
this module, but the recommendation is to override only filter().

=head2 new

Instantiate Doc object.

All of the following params are also available as accessors/mutators.

=over

=item url

=item type

=item content

=item parser

=item modtime

=item size

=item action

=item debug

=item charset

=back

=cut

=head2 init

Calls filter() on object.

=cut

sub init {
    my $self = shift;
    $self->{charset} ||= $charset;
    $self->filter();
    return $self;
}

=head2 filter

Override this method to alter the values in the object prior to it
being process()ed by the Indexer.

The default is to do nothing.

This method can also be set using the filter() callback in SWISH::Prog->new().

=cut

sub filter { }

=head2 as_string

Return the Doc object rendered as a scalar string, ready to be indexed.
This will include the proper headers. See SWISH::Prog::Headers.

B<NOTE:> as_string() is also used if you use a Doc object as a string.
Example:

 print $doc->as_string;     # one way
 print $doc;                # same thing

=cut

# TODO cache this higher up? how else to set debug??
my $headers = SWISH::Prog::Headers->new();

sub as_string {
    my $self = shift;

    # we ignore size() and let Headers compute it based on actual content()
    return $headers->head(
        $self->content,
        {   url     => $self->url,
            modtime => $self->modtime,
            type    => $self->type,
            action  => $self->action,
            parser  => $self->parser
        }
    ) . $self->content;

}

1;

__END__


=pod


=head1 SEE ALSO

L<http://swish-e.org/docs/>

SWISH::Prog::Headers

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
