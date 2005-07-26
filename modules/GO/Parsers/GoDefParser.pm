# $Id$
#
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Parsers::GoDefParser;

=head1 NAME

  GO::Parsers::GoDefParser     - syntax parsing of GO .def flat files

=head1 SYNOPSIS

  do not use this class directly; use GO::Parser

=cut

=head1 DESCRIPTION

This generates Stag event streams from one of the various GO flat file
formats (ontology, defs, xref, associations). See GO::Parser for details

Examples of these files can be found at http://www.geneontology.org

A description of the event streams generated follows; Stag or an XML
handler can be used to catch these events


=head1 GO DEFINITION FILES

These have a suffix .defs or .definitions

  (defs
   (def+
     (godef-goid "s")
     (godef-definition "s")
     (godef-definition_reference+ "s")
     (godef-comment? "s"))) 
 

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


    my @keys =
      qw(
         term
         goid
         id
         definition
         definition_reference
         comment
	);
    my $keymatch =
      '[^\w]('.
        join("|",
             @keys).
               '):\s*';
    $self->start_event("defs");
    my @blocks = ("");
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\!/;
        if (!$line) {
            push(@blocks, "");
        }
        else {
            $blocks[-1] .= "$line ";
        }
    }
    foreach my $block (@blocks) {
        next unless $block;
        $self->line($block);
        $self->line_no(0);
        my @spl = split(/$keymatch/, $block);
        shift @spl;
        my %h = ();
	for (my $i=0; $i<@spl; $i+=2) {
	    my ($k, $v) = ($spl[$i], $spl[$i+1]);
            if ($k eq 'id') { 
                $k = "goid" 
            }
	    if (!$h{$k}) {
		$h{$k} = [];
	    }
	    push(@{$h{$k}}, $v);
	}
        $self->start_event("def");
        if (!$h{definition}) {
            my $msg = "no def for $h{goid} [$block]";
            $self->message($msg);
	    $self->end_event("def");
            next;
        }
        foreach my $k (@keys) {
	    
            my $vals = $h{$k};
            if ($vals) {
		foreach my $v (@$vals) {
		    $v =~ s/ *$//;
		    $self->event("godef-$k", $v);
		}
            }
        }
        $self->end_event("def");
    }
    $self->end_event("defs");
}

1;
