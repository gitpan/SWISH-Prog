package SWISH::Prog::Doc;

use strict;
use warnings;
use Carp;
use base qw( Class::Accessor::Fast );

use POSIX qw(locale_h);
use locale;

use overload('""'     => \&as_string,
             fallback => 1,);

use SWISH::Prog::Headers;

our $VERSION = '0.04';

my @Attr = qw( url modtime type parser content update debug size charset );
__PACKAGE__->mk_accessors(@Attr);
my $locale = setlocale(LC_CTYPE);
my ($lang, $charset) = split(m/\./, $locale);
$charset ||= 'iso-8859-1';

=pod

=head1 NAME

SWISH::Prog::Doc - Document object for passing to Swish-e indexer

=head1 SYNOPSIS

  # subclass SWISH::Prog::Doc
  # and create _filter() methods
  
  package My::Prog::Doc
  use base qw( SWISH::Prog::Doc );
  
  sub url_filter
  {
    my $doc = shift;
    my $url = $doc->url;
    $url =~ s/my.foo.com/my.bar.org/;
    $doc->url( $url );
  }
  
  sub content_filter
  {
    my $doc = shift;
    my $buf = $doc->content;
    $buf =~ s/foo/bar/gi;
    $doc->content( $buf );
  }
  
  1;

=head1 DESCRIPTION

SWISH::Prog::Doc is the base class for Doc objects in the SWISH::Prog
framework. Doc objects are created and returned 
by the SWISH::Prog->fetch() method.

You can subclass SWISH::Prog::Doc and add _filter() methods to alter
the values of the Doc object before it is returned from fetch().

If you subclass SWISH::Prog, you B<MUST> subclass SWISH::Prog::Doc as well,
even if only as a placeholder.

Example:

 package MyApp::Prog;
 use base qw( SWISH::Prog );
 
 sub ok
 {
   my $self = shift;
   my $doc = shift;
   
   1;   # everything is permitted (but not all things are profitable...)
 }
 
 1;
 
 package MyApp::Prog::Doc;  # must use same base class name as above
 
 1;


=head1 METHODS

All of the following methods may be overridden when subclassing
this module.

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

=item update

** Swish-e verison 2.x only **

=item debug

=item charset

=back

=cut

sub new
{
    my $class = shift;
    my $self  = {};
    bless($self, $class);
    $self->_init(@_);
    $self->init();
    $self->filters();
    return $self;
}

sub _init
{
    my $self = shift;
    $self->{'_start'} = time;
    if (@_)
    {
        my %extra = @_;
        @$self{keys %extra} = values %extra;
    }

    $self->{debug} ||= $ENV{PERL_DEBUG} || 0;
    $self->{charset} ||= $charset;
}

=head2 filters

Calls any defined *_filter() methods. Called by new() after init().

=cut

sub filters
{
    my $self = shift;

    # call *_filter for each attribute
    for (@Attr)
    {
        my $f = $_ . '_filter';
        if ($self->can($f))
        {
            $self->$f;
        }
    }

}

=pod

=head2 init

Public initialization method. Override this method in order to initialize a Doc
object. Called in new() after private initialization and before filters().

=cut

sub init { }

=head2 as_string

Return the Doc object rendered as a scalar string, ready to be indexed.
This will include the proper headers. See SWISH::Prog::Headers.

B<NOTE:> as_string() is also used if you use a Doc object as a string.
Example:

 print $doc->as_string;     # one way
 print $doc;                # same thing

=cut

sub as_string
{
    my $self = shift;

    # we ignore size() and let Headers compute it based on actual content()
    return
      SWISH::Prog::Headers->head(
                                 $self->content,
                                 {
                                  url     => $self->url,
                                  modtime => $self->modtime,
                                  type    => $self->type,
                                  update  => $self->update,
                                  parser  => $self->parser
                                 }
                                )
      . $self->content;

}

=head1 FILTERS

Every object attribute may have a *_filter() method defined for it as well.
As part of the object initialization in new(), each attribute is tested with can()
to see if a corresponding _filter() method exists, and if so, the object is passed.
See the SYNOPIS for examples.

Filter method return values are ignored. Save whatever changes you want directly
in the passed object.

=cut

1;

__END__


=pod


=head1 SEE ALSO

L<http://swish-e.org/docs/>

SWISH::Prog::Headers


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

Thanks to www.atomiclearning.com for sponsoring the development
of this module.


=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
