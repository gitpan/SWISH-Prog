package SWISH::Prog::Mail;
use strict;
use warnings;

use Carp;
use Data::Dump qw( dump );
use Search::Tools::XML;
use SWISH::Prog::Mail::Doc;
use Mail::Box::Manager;

use base qw( SWISH::Prog );

__PACKAGE__->mk_accessors(qw( maildir ));

our $VERSION = '0.08';
our $XMLer   = Search::Tools::XML->new;

=pod

=head1 NAME

SWISH::Prog::Mail - index email with Swish-e

=head1 SYNOPSIS
    
    use SWISH::Prog::Mail;
    
    my $prog = SWISH::Prog::Mail->new(
        maildir         => 'path/to/my/maildir',
    );
    
    $prog->create;


=head1 DESCRIPTION

SWISH::Prog::Mail is a SWISH::Prog subclass designed for providing full-text
search for your email with Swish-e.

SWISH::Prog::Mail uses Mail::Box, available from CPAN.

Since SWISH::Prog::Mail inherits from SWISH::Prog, read the SWISH::Prog docs
first. Any overridden methods are documented here.

=head1 METHODS

=head2 new( maildir => I<path> )

Create new indexer object.

B<NOTE:> The new() method simply inherits from SWISH::Prog, so any params
valid for that method() are allowed here.

=head2 init

Initialize object. This overrides SWISH::Prog init() base method.

=cut

sub init {
    my $self = shift;

    $self->{debug} ||= $ENV{PERL_DEBUG} || 0;
}

=pod

=head2 init_indexer

Adds the special C<mail> MetaName to the Config object before
opening indexer.

=cut

sub init_indexer {
    my $self = shift;

    # add top-level metaname
    $self->config->MetaNameAlias('swishdefault mail');

    my @meta = qw(
        url
        id
        subject
        date
        size
        from
        to
        cc
        bcc
        type
        part
    );

    $self->config->MetaNames(@meta);
    $self->config->PropertyNames(@meta);

    # save all body text in the swishdescription property for excerpts
    $self->config->StoreDescription('XML* <body>');

    # TODO get version
    $self->config->write2;

    $self->SUPER::init_indexer();

}

# basic flow:
# recurse through maildir, get all messages,
# convert each message to xml, create Doc object and call index()

=head2 create( I<opts> )

Create index. 

Returns number of emails indexed.

=cut

sub create {
    my $self = shift;
    my %opts = @_;

    my $manager = Mail::Box::Manager->new;

    my $maildir = $self->maildir or croak "maildir required";

    my $folder = $manager->open(
        folderdir => $maildir,
        folder    => '=',
        extract   => 'ALWAYS'
    ) or croak "can't open $maildir";

    $self->process_folder($folder);

    $folder->close( write => 'NEVER' );

    return $self->counter;
}

sub _addresses {
    return join( ', ', map { $_->format } @_ );
}

=head2 process_folder( I<Mail::Box object> )

Recurse through I<Mail::Box> object, indexing all messages. The I<Mail::Box> object
should be a folder as returned from Mail::Box::Manager->new().

=cut

sub process_folder {
    my $self = shift;
    my $folder = shift or croak "folder required";

    my @subs = sort $folder->listSubFolders;

    for my $sub (@subs) {
        my $subf = $folder->openSubFolder($sub);

        warn "searching $sub\n" if $self->verbose;

        foreach my $message ( $subf->messages ) {
            $self->index_mail( $sub, $message );
        }

        $self->process_folder($subf);

        $subf->close( write => 'NEVER' );
    }

}

=head2 filter_attachment( I<msg_url>, I<Mail::Message::Part> )

Run the document represented by I<Mail::Message::Part> object through
SWISH::Filter so attachments are indexed too.

Returns XML content ready for indexing.

=cut

sub filter_attachment {
    my $self    = shift;
    my $msg_url = shift or croak "message url required";
    my $attm    = shift or croak "attachment object required";

    my $type     = $attm->body->mimeType->type;
    my $filename = $attm->body->dispositionFilename;
    my $content  = $attm->decoded;

    if ( $self->swish_filter->can_filter($type) ) {

        my $f = $self->swish_filter->convert(
            document     => \$content,
            content_type => $type,
            name         => $filename,
        );

        if (   !$f
            || !$f->was_filtered
            || $f->is_binary )    # is is_binary necessary?
        {
            warn "skipping $filename in message $msg_url - filtering error\n";
            return '';
        }

        $content = ${ $f->fetch_doc };
    }

    return join( '',
        '<title>',  $XMLer->escape($filename),
        '</title>', $XMLer->escape($content) );

}

=head2 index_mail( I<folder>, I<Mail::Message> )

Extract data and content from I<Mail::Message> in I<folder> and call
index().

=cut

sub index_mail {
    my $self    = shift;
    my $folder  = shift or croak "folder required";
    my $message = shift or croak "mail meta required";

    my %meta = (
        url => join( '.', $folder, $message->messageId ),
        id  => $message->messageId,
        subject => $message->subject || '[ no subject ]',
        date => $message->timestamp,
        size => $message->size,
        from => _addresses( $message->from ),
        to   => _addresses( $message->to ),
        cc   => _addresses( $message->cc ),
        bcc  => _addresses( $message->bcc ),
        type => $message->contentType,
    );

    my @parts = $message->parts;

    for my $part (@parts) {
        push(
            @{ $meta{parts} },
            $self->filter_attachment( $meta{url}, $part )
        );
    }

    $self->mail_filter( \%meta );

    my $title = $self->title_filter( \%meta );

    my $xml = $self->mail2xml( $title, \%meta );

    my $doc = $self->docclass->new(
        content => $xml,
        url     => $meta{url},
        modtime => $meta{date},
        parser  => 'XML*',
        type    => 'application/x-mail',    # TODO is this right?
        mail    => \%meta
    );

    $self->index($doc);

}

=head2 mail2xml( I<title>, I<meta_hash_ref> )

Converts I<meta_hash_ref> to a XML string. Returns the XML.

=cut

sub mail2xml {
    my $self  = shift;
    my $title = shift;
    my $meta  = shift;

    my $xml
        = "<mail>"
        . "<swishtitle>"
        . $XMLer->utf8_safe($title)
        . "</swishtitle>"
        . "<head>";

    for my $m ( sort keys %$meta ) {

        if ( $m eq 'parts' ) {

            $xml .= '<body>';
            for my $part ( @{ $meta->{$m} } ) {
                $xml .= '<part>';
                $xml .= $part;
                $xml .= '</part>';
            }
            $xml .= '</body>';
        }
        else {
            $xml .= $XMLer->start_tag($m);
            $xml .= $XMLer->escape( $meta->{$m} );
            $xml .= $XMLer->end_tag($m);
        }
    }

    $xml .= "</head></mail>";

    return $xml;
}

=head2 title_filter( I<meta_hashref> )

By default the Subject of each mail is used as the title. Override
this method to alter that behaviour.

=cut

sub title_filter {
    my $self = shift;
    my $meta = shift;
    return $meta->{subject};
}

=head2 mail_filter( I<mail> )

Override this method if you need to alter the mail
prior to it being converted to XML for indexing.

This method is called prior to title_filter() so all data is affected.

See FILTERS section.

=cut

sub mail_filter {
    my $self = shift;
    my $mail = shift;

}

1;

__END__

#
# TODO
#

=head1 FILTERS

There are several filtering methods in this module. Here's a summary of what they do
and when they are called, so you have a better idea of how to best use them. Pay special
attention to those called before converting the row to XML as opposed to after conversion.

=head2 mail_filter

Called by index_sql() for each row fetched from the database. This is the first filter
called in the chain. Called before the row is converted to XML.

=head2 title_filter

Called by index_sql() after row_filter() but only if an explicit C<title> opt param was not
passed to index_sql(). Called before the row is converted to XML.

=head2 SWISH::Prog::DBI::Doc *_filter() methods

Each of the normal SWISH::Prog::Doc attributes has a *_filter() method. These are called
after the row is converted to XML. See SWISH::Prog::Doc.

B<NOTE:> There is not a SWISH::Prog::DBI::Doc row_filter() method.

=head2 filter

The normal SWISH::Prog filter() method is called as usual just before passing to ok()
inside index(). Called after the row is converted to XML.


=head1 ENCODINGS

Since Swish-e version 2 does not support UTF-8 encodings, you may need to convert or
transliterate your text prior to indexing. Swish-e offers the TranslateCharacters config
option, but that does not work well with multi-byte characters.

Here's one way to handle the issue. Use Search::Tools::Transliterate and the mail_filter()
method to convert your UTF-8 text to single-byte characters. You can do this by subclassing
SWISH::Prog::Mail and overriding the mail_filter() method.

See SWISH::Prog::DBI for a similar example.

=head1 SEE ALSO

L<http://swish-e.org/docs/>

SWISH::Prog, SWISH::Prog::Mail::Doc, Search::Tools


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

Thanks to rjbs and confounded on #email at irc.perl.org for suggestions on this module.

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
