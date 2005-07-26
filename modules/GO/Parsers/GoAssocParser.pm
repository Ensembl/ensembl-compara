# $Id$
#
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Parsers::GoAssocParser;

=head1 NAME

  GO::Parsers::GoAssocParser     - syntax parsing of GO gene-association flat files

=head1 SYNOPSIS

  do not use this class directly; use GO::Parser

=cut

=head1 DESCRIPTION

This generates Stag event streams from one of the various GO flat file
formats (ontology, defs, xref, associations). See GO::Parser for details

Examples of these files can be found at http://www.geneontology.org

A description of the event streams generated follows; Stag or an XML
handler can be used to catch these events

 
=head2 GO GENE ASSOCIATION FILES

These have the prefix gene_association; eg gene_association.fb

  (assocs
   (dbset
     (proddb "s")
     (prod+
       (prodacc "s")
       (prodsymbol "s")
       (prodtype "s")
       (prodtaxa "i")
       (assoc+
         (assocdate "i")
         (source_db "s")
         (termacc "s")
         (is_not "i")
         (aspect "s")
         (evidence+
           (evcode "s")
           (ref "s")))))) 
 

=head1 AUTHOR

=cut

use Exporter;
use GO::Parsers::BaseParser;
@ISA = qw(GO::Parsers::BaseParser Exporter);

use Carp;
use FileHandle;
use strict qw(subs vars refs);


sub _is_diff {
    my ($x, $y) = @_;
    $x = "" unless defined $x;
    $y = "" unless defined $y;
    $x ne $y;
}
sub ev_filter {
    my $self = shift;
    $self->{_ev_filter} = shift if @_;
    return $self->{_ev_filter};
}



sub skip_uncurated {
    my $self = shift;
    $self->{_skip_uncurated} = shift if @_;
    return $self->{_skip_uncurated};
}

sub parse_fh {
    my ($self, $fh) = @_;
    my $file = $self->file;

    my $product;
    my $term;
    my $assoc;
    my $line_no = 0;

    my @COLS = (0..15);
    my ($PRODDB,
        $PRODACC,
        $PRODSYMBOL,
        $IS_NOT,
        $TERMACC,
        $REF,
        $EVCODE,
        $SEQ_ACC,
        $ASPECT,
        $PRODNAME,
        $PRODSYN,
        $PRODTYPE,
        $PRODTAXA,
        $ASSOCDATE,
	$SOURCE_DB) = @COLS;

    my @mandatory_cols = ($PRODDB, $PRODACC, $TERMACC, $EVCODE);

    #    <assocs>
    #      <dbset>
    #        <db>fb</db>
    #        <prod>
    #          <prodacc>FBgn0027087</>
    #          <prodsym>Aats-his</>
    #          <prodtype>gene</>
    #          <prodtaxa>7227</>
    #          <prodsynonym>...</>
    #          <assoc>
    #            <termacc>GO:0004821</termacc>
    #            <evidence>
    #              <code>NAS</code>
    #              <ref>FB:FBrf0105495</ref>
    #              <with>...</with>
    #            </evidence>
    #          </assoc>
    #        </prod>
    #      </dbset>
    #    <assocs>
 
    $self->start_event("assocs");

    my @last = map {''} @COLS;

    my $skip_uncurated = $self->skip_uncurated;
    my $ev = $self->ev_filter;
    my %evyes = ();
    my %evno = ();
    if ($ev) {
	if ($ev =~ /\!(.*)/) {
	    $evno{$1} = 1;
	}
	else {
	    $evyes{$ev} = 1;
	}
    }

    my $taxa_warning;

    my $line;
    my @vals;
    my @stack = ();
    while (<$fh>) {
        $line_no++;
	chomp;
	if (/^\!/) {
	    next;
	}
	if (!$_) {
	    next;
	}
        s/\\NULL//g;
        $line = $_;

        $self->line($line);
        $self->line_no($line_no);

	@vals = split(/\t/, $line);

	# normalise columns, and set $h
	for (my $i=0; $i<@COLS;$i++) {
	    if (defined($vals[$i])) {

		# remove trailing and
		# leading blanks
		$vals[$i] =~ s/^\s*//;
		$vals[$i] =~ s/\s*$//;

		# sometimes - is used for null
		$vals[$i] =~ s/^\-$//;

		# TAIR seem to be
		# doing a mysql dump...
		$vals[$i] =~ s/\\NULL//;
	    }
	    if (!defined($vals[$i]) ||
		length ($vals[$i]) == 0) {
		if ( grep {$i == $_} @mandatory_cols) {
		    $self->message("no value defined for col ".($i+1)." in line_no $line_no line\n$line\n");
		    next;
		}
	    }
	}
	# let's be strict - it's a good way of detecting errors
	if (!grep {$vals[$ASPECT] eq $_} qw(P C F)) {
	    $self->message("Aspect column says: \"$vals[$ASPECT]\" - aspect must be P/C/F");
	    next;
	}
	if (!($vals[$REF] =~ /:/)) {
	    $vals[$REF] = "medline:$vals[$REF]";
	}
	if ($vals[$SEQ_ACC] eq "IEA") {
	    $self->message("SERIOUS COLUMN PROBLEM: ABORTING");
	    last;
	}
	if ($skip_uncurated && $vals[$EVCODE] eq "IEA") {
	    next;
	}
	if (%evyes && !$evyes{$vals[$EVCODE]}) {
	    next;
	}
	if (%evno && $evno{$vals[$EVCODE]}) {
	    next;
	}
	my $new_dbset = $vals[$PRODDB] ne $last[$PRODDB];
	my $new_prodacc =
	  $vals[$PRODACC] ne $last[$PRODACC] || $new_dbset;
	my $new_assoc =
	  _is_diff($vals[$TERMACC], $last[$TERMACC]) ||
	    $new_prodacc ||
	      _is_diff($vals[$IS_NOT], $last[$IS_NOT]) ||
		_is_diff($vals[$SOURCE_DB], $last[$SOURCE_DB]) ||
		  _is_diff($vals[$ASSOCDATE], $last[$ASSOCDATE]);


	# close finished events
	if ($new_assoc) {
	    $self->pop_stack_to_depth(3) if $last[$TERMACC];
	    #	    $self->end_event("assoc") if $last[$TERMACC];
	}
	if ($new_prodacc) {
	    $self->pop_stack_to_depth(2) if $last[$PRODACC];
	    #	    $self->end_event("prod") if $last[$PRODACC];
	}
	if ($new_dbset) {
	    $self->pop_stack_to_depth(1) if $last[$PRODDB];
	    #	    $self->end_event("dbset") if $last[$PRODDB];
	}
	# open new events
	if ($new_dbset) {
	    $self->start_event("dbset");
	    $self->event("proddb", $vals[$PRODDB]);
	}
	$vals[$PRODTAXA] =~ s/taxonid://i;
	$vals[$PRODTAXA] =~ s/taxon://i;

	if (!$vals[$PRODTAXA]) {
	    if (!$taxa_warning) {
		$taxa_warning = 1;
		$self->message("No NCBI TAXON specified; ignoring");
	    }
	}
	else {
	    if ($vals[$PRODTAXA] !~ /\d+/) {
		if (!$taxa_warning) {
		    $taxa_warning = 1;
		    $self->message("No NCBI TAXON wrong fmt: $vals[$PRODTAXA]");
		    $vals[$PRODTAXA] = "";
		}
	    }
	}
	if ($new_prodacc) {
	    $self->start_event("prod");
	    $self->event("prodacc", $vals[$PRODACC]);
	    $self->event("prodsymbol", $vals[$PRODSYMBOL]);
	    $self->event("prodname", $vals[$PRODNAME]) if $vals[$PRODNAME];
	    $self->event("prodtype", $vals[$PRODTYPE]) if $vals[$PRODTYPE];
	    $self->event("prodtaxa", $vals[$PRODTAXA]) if $vals[$PRODTAXA];
	    my $syn = $vals[$PRODSYN];
	    if ($syn) {
		my @syns = split(/\|/, $syn);
		my %ucheck = ();
		@syns = grep {
		    if ($ucheck{lc($_)}) {
			0;
		    }
		    else {
			$ucheck{lc($_)} = 1;
			1;
		    }
		} @syns;
		map {
		    $self->event("prodsyn", $_);
		} @syns;
	    }
	}
	if ($new_assoc) {
	    my $assocdate = $vals[$ASSOCDATE];
	    $self->start_event("assoc");
	    if ($assocdate) {
		if ($assocdate && length($assocdate) == 8) {
		    $self->event("assocdate", $assocdate);
		}
		else {
		    $self->message("ASSOCDATE wrong format (must be YYYYMMDD): $assocdate");
		}
	    }
	    $self->event("source_db", $vals[$SOURCE_DB])
		    if $vals[$SOURCE_DB];
	    $self->event("termacc", $vals[$TERMACC]);
	    $self->event("is_not", $vals[$IS_NOT] || "0");
	    $self->event("aspect", $vals[$ASPECT]);
	}
	$self->start_event("evidence");
	$self->event("evcode", $vals[$EVCODE]);
	if ($vals[$SEQ_ACC]) {
	    my @seq_accs = split(/\s*\|\s*/, $vals[$SEQ_ACC]);
	    $self->event("seq_acc", $_)
	      foreach @seq_accs;
	    if (@seq_accs > 1) {
		if ($vals[$EVCODE] ne 'IGI' &&
		    $vals[$EVCODE] ne 'IPI' &&
		    $vals[$EVCODE] ne 'ISS' &&
		    $vals[$EVCODE] ne 'IEA'
		   ) {
		    $self->message("cardinality of WITH > 1 [@seq_accs] and evcode $vals[$EVCODE] is NOT RECOMMENDED - see GO docs");
		}
	    }
	}
	map {
	    $self->event("ref", $_)
	} split(/\|/, $vals[$REF]);
	$self->end_event("evidence");
	@last = @vals;
    }
    $fh->close;

    $self->pop_stack_to_depth(0);
#    $self->end_event("assoc");
#    $self->end_event("prod");
#    $self->end_event("dbset");
#    use Data::Dumper;
#    print Dumper $self->handler->{node};
#    $self->end_event("assocs");
}


1;
