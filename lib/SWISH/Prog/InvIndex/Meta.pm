package SWISH::Prog::InvIndex::Meta;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;
use XML::Simple;

our $VERSION = '0.51';

__PACKAGE__->mk_accessors(qw( invindex ));
__PACKAGE__->mk_ro_accessors(qw( file ));

# index metadata. read/write libswish3 file xml format.
#

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->{file} ||= $self->invindex->path->file('swish.xml');
    $self->{data} = XMLin("$self->{file}");

    #warn Data::Dump::dump( $self->{data} );
}

sub AUTOLOAD {
    my $self   = shift;
    my $method = our $AUTOLOAD;
    $method =~ s/.*://;
    return if $method eq 'DESTROY';

    if ( exists $self->{data}->{$method} ) {
        return $self->{data}->{$method};
    }
    croak "no such Meta key: $method";
}

1;

__END__

=pod

=head1 NAME

SWISH::Prog::InvIndex::Meta - read/write InvIndex metadata

=head1 SYNOPSIS

 use SWISH::Prog::InvIndex;
 my $index = SWISH::Prog::InvIndex->new(path => 'path/to/index');
 print $index->meta;  # prints $index->meta->as_string
 
=head1 DESCRIPTION

A SWISH::Prog::InvIndex::Meta object represents the metadata for an
InvIndex. It supports the Swish3 C<swish.xml> header file format only
at this time.

=head1 METHODS

=head2 init

Read and initialize the swish.xml header file.

=head2 file

The full path to the C<swish.xml> file. This is a read-only accessor.

=head2 invindex

The SWISH::Prog::InvIndex object which the SWISH::Prog::InvIndex::Meta
object represents.

=cut

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
