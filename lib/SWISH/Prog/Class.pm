package SWISH::Prog::Class;
use strict;
use warnings;
use base qw( Rose::ObjectX::CAF );
use Carp;
use Data::Dump qw( dump );

our $VERSION = '0.30';

__PACKAGE__->mk_accessors(qw( debug verbose warnings ));

=pod

=head1 NAME

SWISH::Prog::Class - base class for SWISH::Prog classes

=head1 SYNOPSIS

 package My::Class;
 use base qw( SWISH::Prog::Class );
 1;
 
 # see METHODS for what you get for free

=head1 DESCRIPTION

SWISH::Prog::Class is a subclass of Class::Accessor::Fast.
It's a base class useful for making simple accessor/mutator methods.
SWISH::Prog::Class implements some additional methods and features
useful for SWISH::Prog projects.

=head1 METHODS

=head2 new( I<params> )

Constructor. Returns a new object. May take a hash or hashref
as I<params>.

=head2 init

Override init() in your subclass to perform object maintenance at
construction time. Called by new().

=head2 debug

=head2 warnings

=head2 verbose

Get/set flags affecting the verbosity of the program.

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->{debug} = $ENV{PERL_DEBUG} || 0;
    $self->{_start} = time();
    return $self;
}

=head2 elapsed

Returns the elapsed time in seconds since object was created.

=cut

sub elapsed {
    return time() - shift->{_start};
}

=head2 dump( [I<data>] )

Returns $self (and I<data> if present) via Data::Dump::dump. Useful for peering
inside an object or other scalar.

=cut

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
