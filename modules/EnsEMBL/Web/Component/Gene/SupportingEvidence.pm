package EnsEMBL::Web::Component::Gene::SupportingEvidence;

### Displays supporting evidence for all transcripts of a gene

use strict;
use warnings;
use base qw(EnsEMBL::Web::Component::Gene);
use Data::Dumper;

sub _init {
	my $self = shift;
	$self->cacheable( 0 );
	$self->ajaxable(  0 );
}

sub content {
	my $self = shift;
	my $object = $self->object;
	my $type = $object->logic_name;
	my $species = $ENV{'ENSEMBL_SPECIES'}; 
	my $gsi = $object->stable_id;
	my $r = $object->seq_region_name.':'.$object->seq_region_start.'-'.$object->seq_region_end;
	my $html;# = qq(<div class="content">);
	my $e = $object->get_gene_supporting_evidence;
	if (! $e) {
		$html .=  qq(<dt>No Evidence</dt><dd>);
		if ($type =~ /otter/ ){
			$html .= qq(<p>Although this Vega Havana gene has been manually annotated and it's structure is supported by experimental evidence, this evidence is currently missing from the database. We are adding the evidence back to the database as time permits</p>);
		}
		else {
			$html .= qq(<p>No supporting evidence available for this gene</p>);
		}
		return $html;
    }

	$html .= qq(<table class="ss tint">);
	$html .= qq(<tr>
                <th width="20%">Transcript</th>
                <th width="20%">CDS support</th>
                <th width="20%" >UTR support</th>
                <th width="20%">Other transcript support</th>
                <th width="20%">Exon support</th></tr>);
	foreach my $tsi (sort keys %{$e}) {
		my $ln = $e->{$tsi}{'logic_name'};
		my $url = $self->object->_url({
			'type'   => 'Transcript',
			'action' => 'Evidence',
			't'      => $tsi,
		});

		$html .= qq(<tr>
                    <td class="bg2"><a href=\"$url\">$tsi</a> <span class="small">[$ln]</span></td>);
		if (my $trans_evi = $e->{$tsi}{'evidence'}) {
			if (my $cds_ids = $trans_evi->{'CDS'}) {
				$html .= qq(<td>);
				foreach my $link (@{$object->add_evidence_links($cds_ids)}) {
					$html .= qq(
                                <p>$link [align]</p>);
				}
				$html .= qq(</td>);
			} 
			else {
				$html .= qq(<td></td>);
			}

			if (my $utr_ids = $trans_evi->{'UTR'}) {
				$html .= qq(<td>);
				foreach my $link (@{$object->add_evidence_links($utr_ids)}) {
					$html .= qq(
                                <p>$link [align]</p>);
				}
				$html .= qq(</td>);
			}
			else {
				$html .= qq(<td></td>);
			}

			if (my $other_ids= $trans_evi->{'UNKNOWN'}) {
				$html .= qq(<td>);
				foreach my $link (@{$object->add_evidence_links($other_ids)}) {
					$html .= qq(
                                <p>$link [align]</p>);
				}
				$html .= qq(</td>);
			}
			else {
				$html .= qq(<td></td>);
			}
		}
		else {
			$html .= qq(<td colspan=3></td>);
		}
		if (my $extra_evi = $e->{$tsi}{'extra_evidence'}) {
			my $c = scalar(keys(%$extra_evi));
			$html .= qq(
                        <td><a href=\"$url\">$c features</a></td>);
		}
		$html .= qq(</tr>);
	}		
	$html .=  qq(</table>);
	return $html;
}


1;


