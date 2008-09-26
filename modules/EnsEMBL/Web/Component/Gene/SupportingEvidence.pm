package EnsEMBL::Web::Component::Gene::SupportingEvidence;

### Displays supporting evidence for all transcripts of a gene

use strict;
use warnings;
use base qw(EnsEMBL::Web::Component::Gene);
use Data::Dumper;

sub _init {
    my $self = shift;
    $self->cacheable( 0 );
    $self->ajaxable(  1 );
}

sub content {
    my $self = shift;
    my $object = $self->object;
    my $type = $object->logic_name;
    my $o_type = lc($object->get_db);
    my $species = $ENV{'ENSEMBL_SPECIES'}; 
    my $gsi = $object->stable_id;
    my $r = $object->seq_region_name.':'.$object->seq_region_start.'-'.$object->seq_region_end;
    my $html;# = qq(<div class="content">);
    my $e = $object->get_gene_supporting_evidence;
	if (! $e) {
	    $html .=  qq(<dt>No Evidence</dt><dd>);
	    if ($type =~ /otter/ || $o_type eq 'vega'){
		$html .= qq(<p>Although this Vega Havana gene has been manually annotated and it's structure is supported by experimental evidence, this evidence is currently missing from the database. We are adding the evidence back to the database as time permits</p>);
	    }
	    else {
		$html .= qq(<p>No supporting evidence available for this gene</p>);
	    }
	    return $html;
	}

    $html .= qq(<table class="ss tint">);

    #label and space columns - number of these depends on the data
    # - don't mention exon evidence for Vega
    if ($o_type ne 'vega') {
	my $other_evi = 0;
	foreach my $tsi (sort keys %{$e}) {
	    if (my $trans_evi = $e->{$tsi}{'evidence'}) {
		if (my $other_ids = $trans_evi->{'UNKNOWN'}) {
		    $other_evi = 1;
		}
	    }
	}
	if ($other_evi) {
	    $html .= qq(<tr>
                <th width="20%">Transcript</th>
                <th width="20%">CDS support</th>
                <th width="20%">UTR support</th>
                <th width="20%">Other transcript support</th>
                <th width="20%">Exon support</th></tr>);
	}
	else {
	    $html .= qq(<tr>
                <th width="20%">Transcript</th>
                <th width="27%">CDS support</th>
                <th width="27" >UTR support</th>
                <th width="26%">Exon support</th></tr>);
	}
    }
    else {	
	$html .= qq(<tr>
                <th width="20%">Transcript</th>
                <th width="27%">CDS support</th>
                <th width="27" >UTR support</th>
                <th width="26%">Other transcript support</th></tr>);
    }

    #fill the table
    foreach my $tsi (sort keys %{$e}) {
	my $ln = $e->{$tsi}{'logic_name'};
	my $t_url = $self->object->_url({
	    'type'   => 'Transcript',
	    'action' => 'SupportingEvidence',
	    't'      => $tsi,
	});
	my ($trans_evi,$cds_ids,$utr_ids,$other_ids,$exon_evi);
	
	$html .= qq(<tr>
                    <td class="bg2"><a href=\"$t_url\">$tsi</a></td>);	
	if ($trans_evi = $e->{$tsi}{'evidence'}) {
	    if ($cds_ids = $trans_evi->{'CDS'}) {
		$html .= qq(
                            <td>);
		foreach my $link (@{$object->add_evidence_links($cds_ids)}) {
		    my $url = $link->[0];
		    my $id  = $link->[1];
		    my $align_url = $self->object->_url({
			'type'     => 'Transcript',
			'action'   => 'SupportingEvidenceAlignment',
			't'        => $tsi,
			'sequence' => $id,
		    });
		    $html .= qq(
                                <p>$url [<a href=\"$align_url\">align</a>]</p>);
		}
		$html .= qq(</td>);
	    } 
	    else {
		$html .= qq(
                           <td></td>);
	    }
	    
	    if ($utr_ids = $trans_evi->{'UTR'}) {
		$html .= qq(
                            <td>);
		foreach my $link (@{$object->add_evidence_links($utr_ids)}) {
		    my $url = $link->[0];
		    my $id  = $link->[1];
		    my $align_url = $self->object->_url({
			'type'     => 'Transcript',
			'action'   => 'SupportingEvidenceAlignment',
			't'        => $tsi,
			'sequence' => $id,
		    });
		    $html .= qq(
                                <p>$url [<a href=\"$align_url\">align</a>]</p>);
		}
		$html .= qq(</td>);
	    }
	    else {
		$html .= qq(
                            <td></td>);
	    }
	    
	    if ($other_ids = $trans_evi->{'UNKNOWN'}) {
		$html .= qq(
                            <td>);
		foreach my $link (@{$object->add_evidence_links($other_ids)}) {
		    my $url = $link->[0];
		    my $id  = $link->[1];
		    my $align_url = $self->object->_url({
			'type'     => 'Transcript',
			'action'   => 'SupportingEvidenceAlignment',
			't'        => $tsi,
			'sequence' => $id,
		    });
		    $html .= qq(
                                <p>$url [<a href=\"$align_url\">align</a>]</p>);
		}
		$html .= qq(</td>);
	    }
	}
	else {
	    $html .= qq(
                        <td colspan=2></td>);
	}
	if ($exon_evi = $e->{$tsi}{'extra_evidence'}) {
	    my $c = scalar(keys(%$exon_evi));
	    $html .= qq(
                        <td><a href=\"$t_url\">$c features</a></td>);
	}
	$html .= qq(</tr>);
    }		
    $html .=  qq(
                 </table>);
    return $html;
}


1;


