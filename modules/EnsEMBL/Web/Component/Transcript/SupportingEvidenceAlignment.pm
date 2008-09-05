package EnsEMBL::Web::Component::Transcript::SupportingEvidenceAlignment;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::Document::HTML::TwoCol;
use POSIX;


#use Data::Dumper;
#$Data::Dumper::Maxdepth = 3;

sub _init {
    my $self = shift;
    $self->cacheable( 1 );
    $self->ajaxable(  1 );
}

sub caption {
    return undef;
}

sub content {
    my $self = shift;
    my $object = $self->object;
    my $trans = $object->Obj;
    my $table  = new EnsEMBL::Web::Document::HTML::TwoCol;
    my $tsi = $object->stable_id;
    my $input = $object->input;

    my $hit_id = $input->{'sequence'}->[0];
    my $hit_db_name = $object->get_sf_hit_db_name($hit_id);

    #get external sequence and type (DNA or PEP) - refseq try with and without version
    my ($query_db, $ext_seq);
    my @hit_ids = ( $hit_id );
    if ($hit_db_name =~ /^RefSeq/) {
	$query_db = 'RefSeq';
	$hit_id =~ s/\.\d+//;
	push @hit_ids, $hit_id;
    }
    else {
	$query_db = $hit_db_name;
    }

    foreach my $id ( @hit_ids ) {
	$ext_seq = $object->get_ext_seq( $id,uc($query_db) );
	if ($ext_seq) {
	    $hit_id = $id;
	    last;
	}
    }

    #munge hit name for the display
    if ($hit_db_name =~ /^RefSeq/) {
	$ext_seq =~ s/\w+\|\d+\|ref\|//;
	$ext_seq =~ s/\|.+//m;
    }
    if ($hit_db_name =~ /Uniprot/i) {
	$ext_seq =~ s/ .+$//m;
    }
    $ext_seq =~ s /^ //mg; #remove white space from the beginning of each line of sequence

    my $hit_url = $object->get_ExtURL_link( $hit_id, $hit_db_name, $hit_id );

    #working with DNA or PEP ?
    my $seq_type = $object->determine_sequence_type( $ext_seq );
    my $label = $seq_type eq 'PEP' ? 'aa' : 'bp';

    my $ext_seq_length = length($ext_seq);

    my $trans_length = $trans->length;
    my $e_count = scalar(@{$trans->get_all_Exons});
    my $cds_aa_length;
    my $cds_length = '';
    my $tl;
    if ( ($seq_type eq 'PEP') && ($tl = $trans->translation) ) {
	$cds_aa_length = $tl->length;
	$cds_length = " Translation length: $cds_aa_length aa";
    }
    if ($ext_seq) {
	$table->add_row('External record',
			"$hit_url ($hit_db_name), length = $ext_seq_length $label",
			1, );
    }
    $table->add_row('Transcript details',
		    "<p>Exons: $e_count. Length: $trans_length bp.$cds_length</p>",
		    1, );
    my $e_alignment;
    my $html;

    #exon alignment (if exon ID is in the URL)
    if (my $exon_id = $input->{'exon'}->[0]) {
	my $exon;
	#get cached exon off the transcript
	foreach my $e (@{$trans->get_all_Exons()}) {
	    if ($e->stable_id eq $exon_id) {
		$exon = $e;
		last;
	    }
	}

	#get exon sequence
	my ($e_sequence,$e_sequence_length) = @{$object->get_int_seq( $exon, $seq_type, $trans)};

	#get position of exon in the transcript
	my $cdna_start = $exon->cdna_start($trans);
	my $cdna_end  = $exon->cdna_end($trans);

	#length of exon in the CDS
	my $e_length = $exon->length;
	my $e_length_text = "Length: $e_length bp";

	##position of exon in the translation
	my $exon_cds_pos = '';
	if ($seq_type eq 'PEP' && $tl) {
	    #postions of everything we need in cDNA coords
	    my $tl_start  = $exon->cdna_coding_start($trans);
	    my $tl_end    = $exon->cdna_coding_end($trans);
	    my $cds_start = $trans->cdna_coding_start();
	    my $cds_end   = $trans->cdna_coding_end();
	    if ( ! $tl_start || ! $tl_end ) {
		$exon_cds_pos = "<p>Exon is not coding</p>";
	    }
	    else {
		$e_length_text .= " ($e_sequence_length aa)";
		my $start = int(($tl_start - $cds_start )/3 + 1);
		my $end   = int(($tl_end   - $cds_start )/3) + 1;
		$end -= 1 if ($tl_end == $cds_end); #need to take off one since the stop codon is included
		$exon_cds_pos = "<p>CDS: $start-$end aa</p>";
	    }
	}
	$table->add_row('Exon Information',
			"<p>$exon_id</p><p>$e_length_text</p>",
			1, );
	$table->add_row('Exon coordinates',
			"Transcript: $cdna_start-$cdna_end bp</p>$exon_cds_pos",
			1, );

	if ($ext_seq) {
	    #get exon alignment
	    my $e_alignment = $object->get_alignment( $ext_seq, $e_sequence, $seq_type );
	    $table->add_row('Exon alignment',
			    "<p><pre>$e_alignment</pre></p>",
			    1, );
	}
	else {
	    $table->add_row('Exon alignment',
			    "<p>Unable to retrive sequence for $hit_id</p>",
			    1, );
	}
    }

    #get transcript sequence
    my $trans_sequence = $object->get_int_seq($trans,$seq_type)->[0];

    if ($ext_seq) {
	#get transcript alignment
	my $trans_alignment = $object->get_alignment( $ext_seq, $trans_sequence, $seq_type );
	$table->add_row('Transcript alignment',
			"<p><pre>$trans_alignment</pre></p>",
			1, );
    }
    else {
	$table->add_row('Transcript alignment',
			"<p>Unable to retrieve sequence for $hit_id</p>",
			1, );
    }
    return $table->render;
}		

1;

