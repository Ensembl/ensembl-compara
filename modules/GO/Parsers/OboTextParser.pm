# $Id$
#
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Parsers::OboTextParser;

=head1 NAME

  GO::Parsers::OboTextParser     - OBO Flat file parser object

=head1 SYNOPSIS

  do not use this class directly; use GO::Parser

=cut

=head1 DESCRIPTION


=cut

use Exporter;
use GO::Parsers::BaseParser;
use Text::Balanced qw(extract_quotelike extract_bracketed);
@ISA = qw(GO::Parsers::BaseParser Exporter);

use Carp;
use FileHandle;
use strict qw(subs vars refs);



sub parse_fh {
    my ($self, $fh) = @_;
    my $file = $self->file;

    my $is_go;

    $self->start_event("ontology");
    $self->start_event("header");
    my $in_hdr = 1;
    while(<$fh>) {
	chomp;
        s/\!.*//;
        s/\#.*//;
        s/^\s+//;
        s/\s+$//;
	next unless $_;
	if (/^\[(\w+)\]\s*(.*)/) {
	    my $stanza = lc($1);
	    my $rest = $2;
	    if ($in_hdr) {
		$in_hdr = 0;
		$self->end_event("header");
	    }
	    else {
		$self->end_event;
	    }
	    $self->start_event($stanza);
	}
	elsif (/^([\w\-]+)\:\s*(.*)/) {
	    my ($tag, $val) = ($1,$2);
	    if ($tag eq 'relationship') {
		my ($type, $id) = split(' ', $val);
		$val = [[type=>$type],[to=>$id]];
	    }
	    elsif ($tag eq 'def') {
		my ($def, $parts) =
		  $self->extract_qstr($val);
		$val =
		  [[defstr=>$def],
		   map {[dbxref=>$_]} @$parts];
	    }
	    elsif ($tag eq 'synonym') {
		my ($syn, $parts) =
		  $self->extract_qstr($val);
		$val =
		  [[synonymstr=>$syn],
		   map {[dbxref=>$_]} @$parts];
	    }
	    elsif ($tag eq 'remark') {
		my @tvs = split(/\\n/, $val);
		$val = [map {[split(/\\:\s*/, $_)]} @tvs];
	    }
	    else {
		# normal tag:val
	    }
	    $self->event($tag=>$val);
	}
	else {
	    $self->throw("uh oh: $_");
	}
    }
    $self->pop_stack_to_depth(0);
    $self->parsed_ontology(1);
    return;
}

sub extract_qstr {
    my $self = shift;
    my $str = shift;

    my ($extr, $rem, $prefix) = extract_quotelike($str);
    my $txt = $extr;
    $txt =~ s/^\"//;
    $txt =~ s/\"$//;
    if ($prefix) {
	$self->throw("illegal prefix: $prefix");
    }
    my @parts = ();
    while (($extr, $rem, $prefix) = extract_bracketed($rem, '[]')) {
	last unless $extr;
	$extr =~ s/^\[//;
	$extr =~ s/\]$//;
	push(@parts, $extr) if $extr;
    }
    return ($txt, \@parts);
}

1;
