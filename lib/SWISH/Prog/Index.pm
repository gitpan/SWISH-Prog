package SWISH::Prog::Index;

use strict;
use warnings;
use Carp;
use File::Temp;
use File::Copy "move";

use SWISH::Prog::Config;

use base qw/ Exporter Class::Accessor::Fast /;
our @EXPORT = qw/ go /;

our $VERSION = '0.02';

__PACKAGE__->mk_accessors(
    qw/
      name
      config
      fh
      exe
      verbose
      warnings
      native2
      btree2
      debug
      opts
      format

      /
);

=pod

=head1 NAME

SWISH::Prog::Index - handle Swish-e indexing

=head1 SYNOPSIS

 use SWISH::Prog::Index
 my $indexer = SWISH::Prog::Index->new(
                format      => 'native2' || 'btree2',
                config      => SWISH::Prog::Config->new,
                exe         => 'path/to/swish-e',
                verbose     => 0|1|2|3,
                warnings    => 0|1|2|3,
                name        => 'path/to/myindex'
                );
                
 $indexer->run;
 
 print "index files: $_" for $indexer->files;
 
 # or from the command line
 
 DirTree.pl some/path | perl -MSWISH::Prog::Index -e go
 

 
=head1 DESCRIPTION

SWISH::Prog::Index performs Swish-e indexing. For version 2.x
of Swish-e this is simply a convenience wrapper around the B<swish-e>
binary executable.


=head1 FUNCTIONS

=head2 go

Magic method to run the indexer with all defaults. See SYNOPSIS for 
an example.

You might object that the perl line is harder to remember than 
'swish-e -v0 -W0 -S prog -i stdin' and it takes 0.1 second longer
to run.

True enough. But go() was easy to code in two lines, so I did. And it
requires one less keystroke. Laziness is a virtue!

go() is the only export of this module.

=head1 METHODS

=cut

sub go
{
    my $i = __PACKAGE__->new->run;
    while (<>) { print {$i->fh} $_ }
}

=head2 new

Create indexer object. All the following parameters are also accessor methods.

=over

=item name

The name of the index. Should be a file path.

=item config

A SWISH::Prog::Config object.

=item exe

The path to the C<swish-e> executable. If empty, will just look in $ENV{PATH}.

=item verbose

Takes same args as C<swish-e -v> option.

=item warnings

Takes same args as C<swish-e -W> option.

=item format

Tell the indexer what kind of index to expect. Options are C<native2> (default) or
C<btree> (for the experimental incremental feature in version 2.4).

The C<format> param API is subject to change as Swish3 is developed.

=back

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless($self, $class);
    $self->_init(@_);
    return $self;
}

sub _init
{
    my $self = shift;
    $self->{'start'} = time;
    if (@_ == 1 && $_[0]->isa('SWISH::Prog'))
    {
        for ($_[0]->_index_methods)
        {
            $self->$_($_[0]->$_);
        }
    }
    elsif (@_)
    {
        my %extra = @_;
        @$self{keys %extra} = values %extra;
    }

    # set format flag
    $self->{format} ||= 'native2';
    my $f = $self->format;
    $self->$f(1);

    # default name
    $self->{name} ||= 'index.swish-e';
    
    # default config
    $self->{config} ||= SWISH::Prog::Config->new;

}

=pod

=head2 fh

Get or set the open() filehandle for the swish-e process. B<CAUTION:>
don't set unless you know what you're doing.

You can print() to the filehandle using the SWISH::Prog index() method.
Or do it directly like:

 print { $indexer->fh } "your headers and body here";
 
The filehandle is close()'d by the DESTROY magic method in this class.
So when $indexer goes undef, the indexing process is closed automatically.

=cut

sub DESTROY
{
    my $self = shift;
    return 1 unless $self->fh;

    # close indexer filehandle
    my $e = close($self->fh);
    unless ($e)
    {
        if ($? == 0)
        {

            # false positive ??
            return;
        }

        carp "error $e: can't close indexer (\$?: $?): $!\n";

        if ($? == 256)
        {

            # no docs indexed
            # TODO remove temp indexes

        }

    }

}


=head2 rm

Remove the index (all the associated index files).
Useful if creating a temp index for merging, etc.

Returns 0 and carps if there was a problem unlink()ing 
any file. Returns 1 otherwise.

=cut

sub rm
{
    my $self = shift;
    my $r    = 1;
    for my $f ($self->files)
    {
        unless (unlink($f))
        {
            carp "can't unlink $f: $!";    # non-fatal
            $r = 0;
        }
    }
    return $r;
}

=head2 mv( I<new_name> )

Rename the index. Useful if creating temp indexes, etc.

Returns 1 on success, 0 on failure.

=cut

sub mv
{
    my $self = shift;
    my $new  = shift or croak "need new name to mv()";
    my $r    = 1;
    for my $f ($self->files)
    {
        my ($e) = ($f =~ m/(\.(prop|psort|array|file|wdata|btree))$/);
        my $n = defined($e) ? $new . $e : $new;
        unless (move($f, $n))
        {
            carp "can't mv $f -> $n: $!\n";
            $r = 0;
        }
    }

    return $r;
}

=head2 files

Returns a list of all the associated files for the index.

=cut

sub files
{
    my $self = shift;
    my $i    = $self->name;
    my @f;

    # version 2 btree format or native format
    if ($self->native2)
    {
        push(@f, "$i", "$i.prop");
    }
    elsif ($self->btree2)
    {
        push(@f,
             "$i",       "$i.prop",  "$i.array", "$i.file",
             "$i.btree", "$i.psort", "$i.wdata");
    }

    return (@f);
}


=head2 run( [cmd] )

Start the indexer on its merry way. Stores the filehandle
with the B<fh> method for later access via SWISH::Prog or other
methods TBD.

Returns the $indexer object.

You likely don't want to pass I<cmd> in but let run() construct
it for you.

=cut

sub run
{
    my $self = shift;

    my $i = $self->name     || 'index.swish-e';  # TODO different default name??
    my $v = $self->verbose  || 0;
    my $w = $self->warnings || 0;                # suffer the peril!
    my $opts = $self->opts || '';
    my $exe  = $self->exe  || 'swish-e';

    my $cmd = shift || "$exe $opts -f $i -v$v -W$w -S prog -i stdin";

    my $config_file = $self->config->file;
    if ($config_file)
    {
        $cmd .= ' -c ' . $config_file;
    }

    $self->debug and carp "opening: $cmd";

    $| = 1;

    open(SWISH, "| $cmd") or croak "can't exec $cmd: $!\n";

    # must print UTF-8 as is even if swish-e v2 won't index it as UTF-8
    binmode(SWISH, ':utf8');

    $self->fh(*SWISH{IO});

    return $self;    # for the sake of go()
}

=head2 merge( @I<list_of_indexes> )

merge() will merge @I<list_of_indexes> together with the index named in the
calling object.

Returns the $indexer object on success, 0 on failure.

=cut

sub merge
{
    my $self = shift;
    if (!@_)
    {
        croak "merge() requires some indexes to work with";
    }

    # we want a collection of filenames to work with, but
    # we'll accept either a name or an Index object
    my @names;
    for (@_)
    {
        if (ref($_) && $_->isa(__PACKAGE__))
        {
            push(@names, $_->name);
        }
        elsif (ref($_))
        {
            croak "$_ is not a " . __PACKAGE__ . " object";
        }
        else
        {
            push(@names, $_);
        }
    }

    if (scalar(@names) > 60)
    {
        carp "Likely too many indexes to merge at one time!"
          . "Your OS may have an open file limit.";
    }
    my $m = join(' ', @names);
    my $i = $self->name     || 'index.swish-e';  # TODO different default name??
    my $v = $self->verbose  || 0;
    my $w = $self->warnings || 0;                # suffer the peril!
    my $opts = $self->opts || '';
    my $exe  = $self->exe  || 'swish-e';

    # we can't replace the index in-place
    # so we create a new temp index, then mv() back
    my $tmp     = $self->new(name => File::Temp->new->filename);
    my $tmpname = $tmp->name;
    my $cmd     = "$exe $opts -v$v -W$w -M $i $m $tmpname 2>&1";

    my $config_file = $self->config->file;
    if ($config_file)
    {
        $cmd .= ' -c ' . $config_file;
    }

    $self->debug and carp "opening: $cmd";

    $| = 1;

    open(SWISH, "$cmd  |")
      or croak "merge() failed: $!\n";

    while (<SWISH>)
    {
        print STDERR $_ if $self->debug;
    }

    close(SWISH) or croak "can't close merge(): $cmd: $!\n";

    $tmp->mv($self->name) or croak "mv() of temp merge index failed";

    return $self;
}

=head2 add( I<swish_prog_doc_object> )

add() will merge I<swish_prog_doc_object> with the index named in the calling
object. If the existing index uses the btree2 format (incremental mode), that
API will be used. Otherwise, I<swish_prog_doc_object> is indexed as a temporary
index and then merged.

Returns $indexer object on success, 0 on failure.

=cut

sub add
{
    my $self = shift;
    my $doc = shift or croak "need SWISH::Prog::Doc object to add()";
    unless ($doc->isa('SWISH::Prog::Doc'))
    {
        croak "$doc is not a SWISH::Prog::Doc object";
    }

    # it would be nice if the btree flag was accessible somehow via
    # swish-e or the API.
    # instead, we rely on the user to set it in $self->format

    if ($self->format eq 'native2')
    {
        my $tmp =
          $self->new(
                     name     => File::Temp->new->filename,
                     config   => $self->config,
                     verbose  => $self->verbose,
                     warnings => $self->warnings
                    );
        $tmp->run;
        print {$tmp->fh} $doc
          or croak "failed to print to filehandle " . $tmp->fh . ": $!\n";

        $self->merge($tmp)
          or croak "failed to merge " . $tmp->name . " with " . $self->name;

        $tmp->rm or carp "error cleaning up tmp index";

    }
    elsif ($self->format eq 'btree2')
    {

        # TODO
        croak $self->format . " format is not currently supported.";
    }
    else
    {
        croak $self->format . " format is not currently supported.";
    }

    return $self;
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

