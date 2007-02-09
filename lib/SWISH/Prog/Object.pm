package SWISH::Prog::Object;

use strict;
use warnings;

use Carp;
use Data::Dump qw( dump );

# both these next modules are provided if you install YAML::Syck
use YAML::Syck ();
use JSON::Syck ();

use Search::Tools::XML;
use SWISH::Prog::Object::Doc;

use base qw( SWISH::Prog );

__PACKAGE__->mk_accessors(
                qw( methods class title url modtime class_meta serial_format ));

our $VERSION = '0.04';
our $XMLer   = Search::Tools::XML->new;

=pod

=head1 NAME

SWISH::Prog::Object - index Perl objects with Swish-e

=head1 SYNOPSIS

    package My::Object;
    use base qw( SWISH::Prog::Object );
    
    1;
    
    package My::Object::Doc;
    use base qw( SWISH::Prog::Object::Doc );
    
    sub url_filter
    {
        my $doc = shift;
        my $obj = $doc->obj;
        $doc->url( $obj->method_I_want_as_url );
    }
    
    1;
    
    package main;
    use Carp;
    
    my $indexer = My::Object->new(
        methods => [qw( foo bar something something_else )],
        class   => 'My::Class',
        title   => 'mytitle',
        url     => 'myurl',
        modtime => 'mylastmod'
    );
    
    my $data = my_func_for_fetching_data();
    
    # $data is either iterator or arrayref of objects
    $indexer->create( $data );


=head1 DESCRIPTION

SWISH::Prog::Object is a SWISH::Prog subclass designed for providing full-text
search for your Perl objects with Swish-e.

Since SWISH::Prog::Object inherits from SWISH::Prog, read the SWISH::Prog docs
first. Any overridden methods are documented here.

If it seems odd at first to think of indexing objects, consider the advantages:

=over

=item sorting

Particularly for scalar method values, time for sorting objects by method value is greatly
decreased thanks to Swish-e's pre-sorted properties.

=item SWISH::API::Object integration

If you use SWISH::API::Object, you can get a Storable-like freeze/thaw effect with
SWISH::Prog::Object.

=item caching

If some methods in your objects take a long while to calculate values, but don't change
often, you can use Swish-e to cache those values, similar to the Cache::* modules, but
in a portable, fast index.

=back

=head1 METHODS

=head2 new( class => I<classname>, methods => I<array ref of method names to call> )

Create new indexer object.

B<NOTE:> The new() method simply inherits from SWISH::Prog, so any params
valid for that method() are allowed here.

=over

=item methods

The B<methods> param takes an array ref of method names. Each method name
will be called on each object in create(). Each method name will also be stored
as a PropertyName in the Swish-e index, unless you explicitly pass a C<config>
param to new() that defines your PropertyNames.

If not specified, a simple symbol table lookup will be done on I<class>
and all non-built-in methods will be used by default.

=item class

The name of the class each object belongs to. The class value will be stored in the 
index itself for later use with SWISH::API::Object (or for your own amusement).

If not specified, defaults to C<SWISH::Prog::Object::Doc::Instance>.

=item title

Which method to use as the B<swishtitle> value. Defaults to C<title>.

=item url

Which method to use as the B<swishdocpath> value. Defaults to C<url>.

=item modtime

Which method to use as the B<swishlastmodified> value. Defaults to Perl built-in
time().

=item serial_format

Which format to use in serialize(). Default is C<yaml>. You can also use C<json>.
If you don't like either of those, subclass SWISH::Prog::Object and override
serialize() to provide your own format.

=back

=head2 init

Initialize object. This overrides SWISH::Prog init() base method.

=cut

sub init
{
    my $self = shift;

    $self->{debug} ||= $ENV{PERL_DEBUG} || 0;
    $self->{class}   ||= 'SWISH::Prog::Object::Doc::Instance';
    $self->{title}   ||= 'title';
    $self->{url}     ||= 'url';
    $self->{modtime} ||= 'modtime';
    $self->{serial_format} ||= 'yaml';    # better self-reference support

    unless ($self->methods)
    {
        $self->_lookup_methods;
    }

}

sub _lookup_methods
{
    my $self  = shift;
    my $class = $self->class;

        # TODO
        croak
          "Magic method lookup is not yet implemented. Please define your methods explicitly.";

}

=head2 init_indexer

Adds the PropertyNames for each of I<methods>. The special PropertyNamesNoStripChars
config option is used so that all whitespace etc is preserved verbatim.

Each method is also configured as a MetaName. A top level MetaName using the
I<classname> value is also configured.

=cut

sub init_indexer
{
    my $self = shift;

    (my $class_meta = $self->class) =~ s/\W/\./g;
    $self->class_meta($class_meta);

    # set up some defaults unless already explicitly set
    my $config = $self->config;

    # make urls find-able (really should adjust WordCharacters too...)
    $config->MaxWordLimit(256) unless $config->MaxWordLimit;

    # similar to DBI, we alias top-level tag
    # so all words are find-able via swishdefault
    $config->MetaNameAlias('swishdefault ' . $class_meta)
      unless $config->MetaNameAlias;
    $config->MetaNames(@{$self->methods}) unless @{$config->MetaNames};

    $config->PropertyNames(@{$self->methods}) unless @{$config->PropertyNames};
    
    # IMPORTANT to do this because whitespace matters in YAML
    # NOTE that due to swish-e cache buffering, YAML fields
    # that are longer than 10k can get seriously messed up.
    # this is a swish-e bug that should be fixed.
    $config->PropertyNamesNoStripChars(@{$self->methods})
      unless @{$config->PropertyNamesNoStripChars};    

    $config->IndexDescription(
           join(' ', 'class:' . $self->class, 'format:' . $self->serial_format))
      unless $config->IndexDescription;

    # TODO get version
    $config->write2;

    $self->SUPER::init_indexer;

}

=head2 create( I<data> )

Index your objects.

I<data> should either be an array ref of objects, or an iterator object with
two methods: C<done> and C<next>. If I<data> is an iterator, it will be used like:

 until($data->done)
 {
     $indexer->deal_with( $data->next );
 }
 
Returns number of objects indexed.

=cut

sub create
{
    my $self = shift;
    my $data = shift;

    my $counter = 0;

    if (ref($data) eq 'ARRAY')
    {

        for my $o (@$data)
        {
            $self->_index($o);
            $counter++;
        }

    }
    elsif (ref($data) && $data->can('done') && $data->can('next'))
    {
        until ($data->done)
        {
            $self->_index($data->next);
            $counter++;
        }
    }
    else
    {
        croak "\$data $data doesn't look like it's in the expected format";
    }

    return $counter;
}

sub _index
{
    my ($self, $o) = @_;

    my $titlemeth   = $self->title;
    my $urlmeth     = $self->url;
    my $modtimemeth = $self->modtime;

    $o = $self->obj_filter($o);

    my $title =
        $o->can($titlemeth)
      ? $o->$titlemeth
      : $self->title_filter($o);

    my $url =
        $o->can($urlmeth)
      ? $o->$urlmeth
      : $self->counter;

    my $modtime =
        $o->can($modtimemeth)
      ? $o->$modtimemeth
      : time();

    my $xml = $self->obj2xml($self->class_meta, $o, $title);

    my $doc =
      $self->docclass->new(
                           content => $xml,
                           url     => $url,
                           modtime => $modtime,
                           parser  => 'XML*',
                           type    => 'application/object',
                           obj     => $o
                          );

    $self->debug and print $doc;

    $self->index($doc);

}

=head2 obj2xml( I<class>, I<object>, I<title> )

Returns I<object> as an XML string. obj2xml calls the serialize() method
so if you want a serialization format other than the default, override
serialize() in your subclass. See serialize().

=cut

sub obj2xml
{
    my $self = shift;
    my ($class, $o, $title) = @_;

    my $xml =
        $XMLer->start_tag($class)
      . "<swishtitle>"
      . $XMLer->utf8_safe($title)
      . "</swishtitle>";

    for my $m (@{$self->methods})
    {
        my $v = $self->serialize($o, $m);

        my @x =
          ($XMLer->start_tag($m), $XMLer->utf8_safe($v), $XMLer->end_tag($m));

        $xml .= join('', @x);
    }
    $xml .= $XMLer->end_tag($class);

    $self->debug and print STDOUT $xml . "\n";

    return $xml;
}

=head2 serialize( I<object>, I<method_name> )

Returns a serialized (stringified) version of the return value of I<method_name>.
If the return value is already a scalar string (i.e., if ref() returns false)
then the return value is returned untouched. Otherwise, the return value is serialized
with either JSON or YAML, depending on how you configured C<serial_format> in new().

If you subclass SWISH::Prog::Object, then you can (of course) return whatever
serialized format you prefer.

=cut

sub serialize
{
    my $self = shift;
    my ($o, $m) = @_;
    my $v = $o->$m;
    unless (ref $v)
    {
        return $v;
    }
    else
    {
        if ($self->serial_format eq 'json')
        {
            return JSON::Syck::Dump($v);
        }
        elsif ($self->serial_format eq 'yaml')
        {
            return YAML::Syck::Dump($v);
        }
        else
        {
            croak "unknown serial_format: " . $self->serial_format;
        }
    }

}

=head2 obj_filter( I<object> )

Override this method if you need to alter the object data prior to being
indexed.

This method is called prior to title_filter() so all object data is affected.

B<NOTE:> This is different from the obj() method in
the ::Doc subclass. This obj_filter() gets called before the Doc object
is created.

B<IMPORTANT:> This method B<MUST> return an object. It can either be the same
object I<object> that was passed in, or a different object altogether. An example
might be if you took data from I<object> and created a new object in a different
class (or even the same one).

Example:

 sub obj_filter
 {
    my ($prog,$obj) = @_;
    
    my $newobj = SomeClass->new;
    $newobj->foo( $obj->bar );
    
    return $newobj; # MUST return an object. Need not be $obj
 }

=cut

sub obj_filter
{
    my $self = shift;
    my $obj  = shift;
    return $obj;

}

=head2 title_filter( I<object> )

Override this method if you do not provide a C<title> param in new()
or if you have no C<title> method to call on I<object>.

The return value of title_filter() will be used as the C<swishtitle> for the
object's virtual XML document.

=cut

sub title_filter
{
    my $self = shift;
    my $obj  = shift;
    return "$obj";    # just perl scalar value
}

1;

__END__


=head1 REQUIREMENTS

L<SWISH::Prog>, L<Data::Dump>

=head1 LIMITATIONS and BUGS

L<SWISH::Prog::Object> cannot index method values that are not scalars,
array refs or hash refs, due to how reference values stringify with Data::Dump.

=head1 SEE ALSO

L<http://swish-e.org/docs/>

L<SWISH::Prog>, L<SWISH::API:Object>


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

Thanks to Atomic Learning for supporting the development of this module.

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
