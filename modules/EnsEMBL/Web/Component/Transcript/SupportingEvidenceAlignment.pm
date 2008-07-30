package EnsEMBL::Web::Component::Transcript::SupportingEvidenceAlignment;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use EnsEMBL::Web::ExtIndex;

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
    my $tsi = $object->stable_id;
    my $input = $object->input;

    my $hit_id = $input->{'sequence'}->[0];
    my $hit_db_name = $object->get_hit_db_name($hit_id);
    my $hit_url = $object->get_ExtURL_link( $hit_id, $hit_db_name, $hit_id );

    #get external sequence and type (DNA or PEP)
    my $query_db = ($hit_db_name =~ /^RefSeq/) ? 'RefSeq' : $hit_db_name;
    my $ext_seq = $object->get_ext_seq( $hit_id,uc($query_db) );
    unless( $ext_seq ) {
	$object->problem( 'fatal', "External Feature Alignment Does Not Exist", "The sequence for feature $hit_id could not be retrieved.");
	return;
    }
    #worting with DNA or PEP ?
    my $seq_type = $object->determine_sequence_type( $ext_seq );

    my $ext_seq_length = length($ext_seq);
    my $label = $seq_type eq 'PEP' ? 'aa' : 'bp'; 

    my $html;

    #exon alignment (if exon ID is in the URL)
    if (my $exon_id = $input->{'exon'}->[0]) {
	my $exon;
	#get cached exon off the transcript
	foreach my $e (@{$object->Obj->get_all_Exons()}) {
	    if ($e->stable_id eq $exon_id) {
		$exon = $e;
		last;
	    }
	}
	#get exon sequence
	my $e_sequence  = $object->get_int_seq( $exon, $seq_type, $object->Obj);
	my $e_length = $exon->length;
	#get exon alignment
	my $e_alignment = $object->get_alignment( $ext_seq, $e_sequence, $seq_type );
	$html .= qq(<div class="content">);
	$html .= qq(<p>Exon $exon_id ($e_length bp) aligned with $hit_url ($hit_db_name) ($ext_seq_length $label)</p>);
	$html .= qq(<p><pre>$e_alignment</pre></p>);
	$html .= qq(</div>);
    }

    #get transcript sequence
    my $trans_sequence = $object->get_int_seq( $object->Obj, $seq_type);
    #get transcript alignment
    my $trans_alignment =  $object->get_alignment( $ext_seq, $trans_sequence, $seq_type );
    my $trans_length = $object->Obj->length;

    $html .= qq(<div class="content">);
    $html .= qq(<p>Transcript $tsi ($trans_length bp) aligned with $hit_url ($hit_db_name) ($ext_seq_length $label)</p>);
    $html .= qq(<p><pre>$trans_alignment</pre></p>);
    $html .= qq(</div>);
    return $html;
}		

1;

