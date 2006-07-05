package SWISH::Prog::Index;

use strict;
use warnings;
use Carp;

use SWISH::Prog::Config;

use base qw/ Exporter Class::Accessor /;
our @EXPORT = qw/ go /;

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
      swish3
      debug
      opts
      
      
      /
);

=pod

=head1 NAME

SWISH::Prog::Index - handle Swish-e indexing

=head1 SYNOPSIS

 use SWISH::Prog::Index
 my $indexer = SWISH::Prog::Index->new(
                format      => 'native2' || 'btree2' || 'swish3',
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
of Swish-e this is simply a convenience wrapper around the swish-e
binary executable. See L<SWISH3> for details about how version 3 will work.


=head1 FUNCTIONS

=head2 go

Magic method to run the indexer with all defaults. See SYNOPSIS for 
an example.

You might object that the perl line is harder to remember than 
'swish-e -v0 -W0 -S prog -i stdin' and it takes 0.1 second longer
to run.

True enough. But go() was easy to code in two lines, so I did. And it
requires one less keystroke. Laziness is a virtue!

Plus, Swish3 will have a native Perl XS API, and
this module will support all versions with go().
See ENVIRONMENT VARIABLES for more details.

go() is the only export of this module.

=head1 METHODS

=cut

sub go
{
    my $i = __PACKAGE__->new->run;
    while (<>) { print {$i->fh} $_ }
}

=head2 new

Create indexer object.

[TODO parameters]

=cut

sub new
{
    my $class = shift;
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
        for (qw/ name verbose opts debug config /)
        {
            $self->$_( $_[0]->$_ );
        }
    }
    elsif (@_)
    {
        my %extra = @_;
        @$self{keys %extra} = values %extra;
    }

    # set format flag
    my $f = $self->{format} || 'native2';
    $self->$f(1);
    
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
    unless ( $e )
    {
        if ( $? == 0 )
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

=pod

=head2 rm

Remove the index (all the associated index files).
Useful if creating a temp index for merging, etc.

=cut

sub rm
{
    my $self = shift;
    for my $f ($self->files)
    {
        unlink($f) or warn "can't unlink $f: $!\n";    # non-fatal
    }
}

=pod

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
    elsif ($self->swish3)  # TODO
    {
        push(@f, "$i", "$i.prop");
    }

    return (@f);
}

=pod

=head2 run

Start the indexer on its merry way. Stores the filehandle
with the B<fh> method for later access via SWISH::Prog or other
methods TBD.

Returns the $indexer object.

=cut

sub run
{
    my $self = shift;

    # TODO Swish3 XS support

    my $i    = $self->name     || 'index.swish-e';      # TODO different default name??
    my $v    = $self->verbose  || 0;
    my $w    = $self->warnings || 0;                     # suffer the peril!
    my $opts = $self->opts     || '';
    my $exe  = $self->exe      || 'swish-e';
    
    my $cmd = "$exe $opts -f $i -v$v -W$w -S prog -i stdin";
    
    my $config_file = $self->config->file;
    if ($config_file)
    {
        $cmd .= ' -c ' . $config_file;
    }
    
    $self->debug and carp "opening: $cmd";

    $| = 1;

    open(SWISH, "| $cmd") or croak "can't exec $cmd: $!\n";

    # must print UTF-8 as is
    binmode(SWISH, ':utf8');

    $self->fh(*SWISH{IO});

    return $self;                                        # for the sake of go()
}

=pod

=head1 SWISH3

If the C<SWISH3> environment variable is set, SWISH::Prog::Index will load 
SWISH::Prog::Index::3 and use that interface instead. 

=cut

1;

__END__


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

