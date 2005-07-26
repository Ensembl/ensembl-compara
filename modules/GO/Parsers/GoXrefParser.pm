# $Id$
#
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Parsers::GoXrefParser;

=head1 NAME

  GO::Parsers::GoXrefParser     - syntax parsing of GO xref flat files (eg eg2go, metacyc2go)

=head1 SYNOPSIS

  do not use this class directly; use GO::Parser

=cut

=head1 DESCRIPTION

This generates Stag event streams from one of the various GO flat file
formats (ontology, defs, xref, associations). See GO::Parser for details

Examples of these files can be found at http://www.geneontology.org

A description of the event streams generated follows; Stag or an XML
handler can be used to catch these events

=head1 GO XREF FILES

These files have a filename *2go; eg metacyc2go

  (dbxrefs
   (termdbxref+
     (termacc "s")
     (dbxref
       (xref_dbname "s")
       (xref_key "s")))) 

 

=head1 AUTHOR

=cut

use Exporter;
use GO::Parsers::BaseParser;
@ISA = qw(GO::Parsers::BaseParser Exporter);

use Carp;
use FileHandle;
use strict qw(subs vars refs);

sub acc2termname {
    my $self = shift;
    $self->{_acc2termname} = shift if @_;
    return $self->{_acc2termname};
}

sub parse_fh {
    my ($self, $fh) = @_;
    my $file = $self->file;

    my $lnum = 0;
    $self->start_event("dbxrefs");
    while (<$fh>) {
        chomp;
        $lnum++;
        next if /^\!/;
        next if /^$/;
        $self->line($_);
        $self->line_no($lnum);
        if (/(\w+):?(.*)\s+\>\s+(.+)\s+;\s+(.+)/) {
            my ($db, $dbacc, $goname, $goacc) = ($1, $2, $3, $4);
            my @goaccs = split(/\, /, $goacc);
            foreach $goacc (@goaccs) {
                $self->start_event("termdbxref");
                $self->event(termacc=>$goacc);
                $self->start_event("dbxref");
                $self->event(xref_dbname => $db);
                $self->event(xref_key => $dbacc);
                $self->end_event("dbxref");
                $self->end_event("termdbxref");
            }
        }
        else {
            $self->message("cannot parse this line");
        }
    }
    $self->end_event("dbxrefs");
}

1;
