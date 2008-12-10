package SWISH::Prog::Config;

=head1 NAME

SWISH::Prog::Config - read & write Swish-e config files

=head1 SYNOPSIS

 use SWISH::Prog::Config;
 
 my $config = SWISH::Prog::Config->new;
 
 
=head1 DESCRIPTION

The SWISH::Prog::Config class is intended to be accessed via SWISH::Prog new().

See the Swish-e documentation for a list of configuration parameters.
Each parameter has an accessor/mutator method as part of the Config object.
Some preliminary compatability is offered for Swish::Config
with XML format config files.

B<NOTE:> Every config parameter can take either a scalar or an array ref as a value.
In addition, you may append config values to any existing values by passing an additional
true argument. The return value of any 'get' is always an array ref.

Example:

 $config->MetaNameAlias( ['foo bar', 'one two', 'red yellow'] );
 $config->MetaNameAlias( 'green blue', 1 );
 print join("\n", @{ $config->MetaNameAlias }), " \n";
 # would print:
 # foo bar
 # one two
 # red yellow
 # green blue
 


=head1 METHODS

NOTE this class inherits from Class::Accessor and not SWISH::Prog::Class.

=head2 new( I<params> )

Instatiate a new Config object. Takes a hash of key/value pairs, where each key
may be a Swish-e configuration parameter.

Example:

 my $config = SWISH::Prog::Config->new( DefaultContents => 'HTML*' );
 
 print "DefaultContents is ", $config->DefaultContents, "\n";
 
=cut

use strict;
use warnings;
use Carp;
use File::Slurp;
use Config::General;
use Data::Dump qw( dump );
use File::Temp qw( tempfile );
use Search::Tools::XML;
use Path::Class qw();    # we have our own file() method
use overload(
    '""'     => \&stringify,
    fallback => 1,
);

our $VERSION = '0.22';

our $XMLer = Search::Tools::XML->new;

# can't use SWISH::Prog::Class because we override the get/set magic.
use base qw( Class::Accessor );

my %unique = map { $_ => 1 } qw(
    MetaNames
    PropertyNames
    PropertyNamesNoStripChars

);

my @Opts = qw(
    AbsoluteLinks
    BeginCharacters
    BumpPositionCounterCharacters
    Buzzwords
    ConvertHTMLEntities
    DefaultContents
    Delay
    DontBumpPositionOnEndTags
    DontBumpPositionOnStartTags
    EnableAltSearchSyntax
    EndCharacters
    EquivalentServer
    ExtractPath
    FileFilter
    FileFilterMatch
    FileInfoCompression
    FileMatch
    FileRules
    FollowSymLinks
    FuzzyIndexingMode
    HTMLLinksMetaName
    IgnoreFirstChar
    IgnoreLastChar
    IgnoreLimit
    IgnoreMetaTags
    IgnoreNumberChars
    IgnoreTotalWordCountWhenRanking
    IgnoreWords
    ImageLinksMetaName
    IncludeConfigFile
    IndexAdmin
    IndexAltTagMetaName
    IndexComments
    IndexContents
    IndexDescription
    IndexDir
    IndexFile
    IndexName
    IndexOnly
    IndexPointer
    IndexReport
    MaxDepth
    MaxWordLimit
    MetaNameAlias
    MetaNames
    MetaNamesRank
    MinWordLimit
    NoContents
    obeyRobotsNoIndex
    ParserWarnLevel
    PreSortedIndex
    PropCompressionLevel
    PropertyNameAlias
    PropertyNames
    PropertyNamesCompareCase
    PropertyNamesDate
    PropertyNamesIgnoreCase
    PropertyNamesMaxLength
    PropertyNamesNoStripChars
    PropertyNamesNumeric
    PropertyNamesSortKeyLength
    RecursionDepth
    ReplaceRules
    ResultExtFormatName
    SpiderDirectory
    StoreDescription
    SwishProgParameters
    SwishSearchDefaultRule
    SwishSearchOperators
    TmpDir
    TranslateCharacters
    TruncateDocSize
    UndefinedMetaTags
    UndefinedMetaNames
    UndefinedXMLAttributes
    UseSoundex
    UseStemming
    UseWords
    WordCharacters
    Words
    XMLClassAttributes
);

__PACKAGE__->mk_accessors( qw( file debug verbose ), @Opts );

sub new {
    my $class = shift;
    my $opts  = ref( $_[0] ) ? $_[0] : {@_};
    my $self  = $class->SUPER::new($opts);
    $self->{'_start'} = time;
    $self->IgnoreTotalWordCountWhenRanking(0)
        unless defined $self->IgnoreTotalWordCountWhenRanking;
    return $self;
}

=head2 set

Override the Class::Accessor method.

=cut

sub set {
    my $self = shift;
    my ( $key, $val, $append ) = @_;

    if ( $key eq 'file' or $key eq 'debug' ) {
        return $self->{$key} = $val;
    }
    elsif ( exists $unique{$key} ) {
        return $self->_name_hash(@_);
    }

    $self->{$key} = [] unless defined $self->{$key};

    # save everything as an array ref regardless of input
    if ( ref $val ) {
        if ( ref($val) eq 'ARRAY' ) {
            $self->{$key} = $append ? [ @{ $self->{$key} }, @$val ] : $val;
        }
        else {
            croak "$key cannot accept a " . ref($val) . " ref as a value";
        }
    }
    else {
        $self->{$key} = $append ? [ @{ $self->{$key} }, $val ] : [$val];
    }

}

=head2 get

Override the Class::Accessor method.

=cut

sub get {
    my $self = shift;
    my $key  = shift;

    if ( exists $unique{$key} ) {
        return $self->_name_hash($key);
    }
    else {
        return $self->{$key};
    }
}

sub _name_hash {
    my $self = shift;
    my $name = shift;

    if (@_) {

        #carp "setting $name => " . join(', ', @_);
        for my $v (@_) {
            my @v = ref $v ? @$v : ($v);
            $self->{$name}->{ lc($_) } = 1 for @v;
        }
    }
    else {

        #carp "getting $name -> " . join(', ', sort keys %{$self->{$name}});

    }

    return [ sort keys %{ $self->{$name} } ];
}

=head2 read2( I<path/file> )

Reads version 2 compatible config file and stores in current object.
Returns parsed config file as a hashref or undef on failure to parse.

Example:

 use SWISH::Prog::Config;
 my $config = SWISH::Prog::Config->new();
 my $parsed = $config->read2( 'my/file.cfg' );
 
 # should print same thing
 print $config->WordCharacters->[0], "\n";
 print $parsed->{WordCharacters}, "\n";
 
 
=cut

sub read2 {
    my $self = shift;
    my $file = shift or croak "version2 type file required";

    # stringify $file in case it is a Path::Class object
    my $buf = read_file($file);

    # filter include syntax to work with Config::General's
    $buf =~ s,IncludeConfigFile (.+?)\n,<<include $1>>\n,g;

    my $dir = Path::Class::File->new($file)->parent;

    # TODO are these the right opts?
    my $c = Config::General->new(
        -String          => $buf,
        -IncludeRelative => 1,
        -ConfigPath      => [$dir]
    ) or return;

    my %conf = $c->getall;

    for ( keys %conf ) {
        my $v = $conf{$_};
        $self->$_($v);
    }

    return \%conf;
}

=head2 write2( I<path/file> )

Writes version 2 compatible config file.

If I<path/file> is omitted, a temp file will be
written using File::Temp.

Returns full path to file.

Full path is also available via file() method.


=head2 file

Returns name of the file written by write2().


=cut

sub write2 {
    my $self = shift;
    my $file = shift;
    my $path = $file;
    unless ($file) {
        ( $file, $path ) = tempfile();
    }

    my $buf = $self->stringify;
    write_file( $file, $buf );

    print STDERR "wrote config file $path using $file" if $self->debug;

    # remember file
    $self->file($path);

    return $path;
}

=head2 as_hash

Returns current Config object as a hash ref.

=cut

sub as_hash {
    my $self = shift;
    my $c = Config::General->new( -String => $self->stringify );
    return { $c->getall };
}

=head2 stringify

Returns object as version 2 formatted scalar.

This method is used to overload the object for printing, so these are
equivalent:

 print $config->stringify;
 print $config;

=cut

sub stringify {
    my $self = shift;
    my @config;

   # must pass metanames and properties first, since others may depend on them
   # in swish config parsing.
    for my $method ( keys %unique ) {
        my $v = $self->$method;

        next unless scalar(@$v);

        #carp "adding $method to config";
        push( @config, "$method " . join( ' ', @$v ) );
    }

    for my $name (@Opts) {
        next if exists $unique{$name};

        my $v = $self->$name;
        next unless defined $v;
        if ( ref $v ) {
            push( @config, "$name $_" ) for @$v;
        }
        else {
            push( @config, "$name $v" );
        }
    }

    my $buf = join( "\n", @config ) . "\n";

    print STDERR $buf if $self->debug;

    return $buf;
}

sub _write_utf8 {
    my ( $self, $file, $buf ) = @_;
    binmode $file, ':utf8';
    print {$file} $buf;
}

=head2 ver2_to_xml( I<file> )

Utility method for converting Swish-e version 2 style config files
to SWISH::Config XML style.

Converts I<file> to XML format and returns as XML string.

B<NOTE:> This API is liable to change as SWISH::Config is developed.

  my $xmlconf = $config->ver2_to_xml( 'my/file.config' );

If I<file> is omitted, uses the current values in the calling object.

=cut

sub ver2_to_xml {
    my $self = shift;
    my $file = shift;

    # list of config directives that take arguments to the opt value
    # i.e. the directive has 3 or more parts
    my %takes_arg = map { $_ => 1 } qw(

        StoreDescription
        PropertyNamesSortKeyLength
        PropertyNamesMaxLength
        PropertyNameAlias
        MetaNameAlias
        IndexContents
        IgnoreWords
        ExtractPath
        FileFilter
        FileRules
        ReplaceRules
        Words

    );

    my $config = $file ? $self->new->read2($file) : $self->as_hash;
    my $time = localtime();

    # TODO  what if this encoding is not correct?
    my $xml = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<!-- converted with SWISH::Prog::Config ver2_to_xml() $time -->
<swishconfig>
EOF

KEY: for my $k ( sort keys %$config ) {
        my @args = ref $config->{$k} ? @{ $config->{$k} } : ( $config->{$k} );

    ARG: for my $arg (@args) {
            $xml .= "  <$k";
            if ( $takes_arg{$k} ) {
                my ( $class, $v ) = ( $arg =~ m/^\ *(\S+)\ +(.+)$/ );
                $arg = $v;
                $xml .= ' type="' . $XMLer->utf8_safe($class) . '"';
            }
            $xml .= '>' . $XMLer->utf8_safe($arg) . "</$k>\n";

        }
    }

    $xml .= "</swishconfig>\n";

    return $xml;

}

1;

__END__

=head1 TODO

IgnoreTotalWordCountWhenRanking defaults to 0 which is B<not> the default in Swish-e.
This is to make the RankScheme feature work by default. Really, the default should be
0 in Swish-e itself.

=head1 SEE ALSO

SWISH::Prog, SWISH::Parser

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
