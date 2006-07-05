package SWISH::Prog::Config;

=pod

=head1 NAME

SWISH::Prog::Config - read & write Swish-e config files

=head1 SYNOPSIS

 use SWISH::Prog::Config;
 
 my $config = SWISH::Prog::Config->new;
 
 
=head1 DESCRIPTION

The Config class is intended to be accessed via SWISH::Prog new().

See the Swish-e documentation for a list of configuration parameters.
Each parameter has an accessor/mutator method as part of the Config object.
Forwards-compatability is offered for Swish3 with XML format config files.

=head1 METHODS

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
use File::Temp qw/ tempfile /;
use File::Slurp;
use Search::Tools::XML;

our $XMLer = Search::Tools::XML->new;

use base qw( Class::Accessor::Fast );

# TODO - better way
# prepend some with _ that we have custom methods for

my @Ver2C = qw/

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
      EquivalentServerserver
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
      _MetaNames
      MinWordLimit
      NoContents
      obeyRobotsNoIndex 
      ParserWarnLevel 
      PreSortedIndex
      PropCompressionLevel 
      PropertyNameAlias
      _PropertyNames
      PropertyNamesCompareCase
      PropertyNamesDate
      PropertyNamesIgnoreCase
      PropertyNamesMaxLength
      _PropertyNamesNoStripChars
      PropertyNamesNumeric
      PropertyNamesSortKeyLength
      ReplaceRules 
      ResultExtFormatName
      SpiderDirectory
      StoreDescription 
      SwishProgParameters
      SwishSearchDefaultRule 
      SwishSearchOperators
      TmpDirpath
      TranslateCharacters 
      TruncateDocSize
      UndefinedMetaTags 
      UndefinedXMLAttributes 
      UseSoundex 
      UseStemming
      UseWords
      WordCharacters
      XMLClassAttributes


  /;

sub new
{
    my $package = shift;
    my $self    = {};
    bless($self, $package);
    $self->_init(@_);
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

    $self->mk_accessors(qw/ file debug /, @Ver2C);

}


# TODO others that require 'array' of values?

sub _name_hash
{
    my $self = shift;
    my $name = shift;

    if (@_)
    {

        #carp "setting $name => " . join(', ', @_);

        for (@_)
        {
            $self->{$name}->{$_} = 1;
        }
    }
    else
    {

        #carp "getting $name -> " . join(', ', sort keys %{$self->{$name}});
        return (sort keys %{$self->{$name}});
    }
}

=head2 metanames

Get/set list of Metanames.

=cut

sub metanames
{
    my $self = shift;
    return $self->_name_hash('_metanames', @_);
}

=head2 propertynames

Get/set list of PropertyNames.

=cut

sub propertynames
{
    my $self = shift;
    return $self->_name_hash('_propertynames', @_);
}

=head2 propertynamesnostripchars

Get/set list of PropertyNamesNoStripChars.

=cut

sub propertynamesnostripchars
{
    my $self = shift;
    return $self->_name_hash('_propertynamesnostripchars', @_);
}

=head2 file

Returns name of the file written by write2().


=head2 write2( I<file/path> )

Writes version 2 compatible config file.

If I<file/path> is omitted, a temp file will be
written using File::Temp.

Returns full path to file.

Full path is also available via file() method.

=cut

sub write2
{
    my $self = shift;
    my $file = shift;
    my $path = $file;
    unless ($file)
    {
        ($file, $path) = tempfile();
    }

    my @config;
    for my $name (@Ver2C)
    {
        my $v = $self->$name;
        next unless $v;
        push(@config, "$name $v");

    }
    
    for (qw/ MetaNames PropertyNames PropertyNamesNoStripChars /)
    {
        my $method = lc($_);
        my @v      = $self->$method;

        #carp "checking $_ => $method: " . join(', ', @v);
        # can't just check $self->$method for TRUE
        # must get @v instead
        if (@v)
        {

            #carp "adding $_ to config";
            push(@config, "$_ " . join(' ', @v));
        }
    }

    my $buf = join("\n", @config) . "\n";
    
    print STDERR $buf if $self->debug;
    
    write_file($file, $buf);

    # remember file
    $self->file($path);

    return $path;
}

=head2 ver2_to_ver3( @I<files> )

Utility method for converting Swish-e version 2 style config files
to Swish3 XML style.

Takes an array of version 2 files and converts each to version 3
format, writing to same location with C<.xml> appended.

B<NOTE:> Some version 2 configuration options are not forward-compatible with 
version 3 and will be carp()ed about if found.

=cut

sub ver2_to_ver3
{
    my $self  = shift;
    my @files = @_;

    my $re = qr/^(\S+)\s+(\S+)\s*(.*)$/o;

    # list of config directives that take arguments to the opt value
    my %takes_arg = ();
    $takes_arg{$_}++ for (
        qw/

        StoreDescription
        PropertyNamesSortKeyLength
        PropertyNamesMaxLength
        PropertyNameAlias
        MetaNameAlias
        IndexContents
        IgnoreWords
        ExtractPath
        FileFilter

        /
    );

    # TODO: skip list of deprecated options and give helpful warning
    # FileRules
    # FileFilter
    # FileFilterMatch
    # FileMatch
    # EquivalentServer
    # MaxDepth
    # Delay
    # TmpDir
    # ReplaceRules
    # SpiderDirectory

    # TODO: convert *WordChar to Ignore*Char

    for my $old (@files)
    {

        my $new = "$old.xml";

        open(OLD, "< $old") or die "can't read $old: $!\n";
        open(NEW, "> $new") or die "can't write $new: $!\n";

        my $time = localtime();

        # TODO  what if this encoding is not correct?

        print NEW qq{<?xml version="1.0" encoding="iso-8859-1"?>};

        print NEW "<!-- converted from $old at $time -->\n";

        print NEW "<config>\n";

        # TODO join split lines
        # e.g.,
        # foo bar \
        #  baz

        while (<OLD>)
        {

            next if m/^(\s+|#)/;

            my ($name, $val, $args) = m!$re!;
            my @i = split(/\s+/, $args);

            unshift(@i, $val) unless exists $takes_arg{$name};

            # each value gets its own tagset

            # concatenate " " marks
            if ($i[0] =~ m/^(['"])/)
            {
                my $q = $1;
                while ($i[0] !~ m/$q$/)
                {
                    $i[0] .= ' ' . splice(@i, 1, 1);
                }
            }

            for my $v (@i)
            {

                $v =~ s/^['"]|['"]$//g;

                print NEW "  <$name";
                if (exists $takes_arg{$name})
                {
                    print NEW ' v="' . $XMLer->utf8_safe($val) . '"';
                }
                print NEW '>' . $XMLer->utf8_safe($v);
                print NEW "</$name>\n";

            }

        }

        print NEW "</config>\n";

        close(OLD);
        close(NEW);

        print "$old saved as $new\n";

    }

}

1;

__END__


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
