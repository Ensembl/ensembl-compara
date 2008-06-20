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
		$html .=  qq( <dt>No Evidence</dt><dd>);
		if ($type =~ /otter/ ){
			$html .= qq(<p>Although this Vega Havana gene has been manually annotated and it's structure is supported by experimental evidence, this evidence is currently missing from the database. We are adding the evidence back to the database as time permits</p>);
		}
		else {
			$html .= qq(<p>No supporting evidence available for this gene</p>);
		}
		return $html;
    }

	$html .= qq(<table class="ss tint">);
	$html .= qq(<tr><th width="16%">Transcript</th><th width="28%"></th><th width="28%" >View record</th><th width="28%">View alignment</th></tr>);
	foreach my $tsi (sort keys %{$e}) {
		$html .= qq(<tr>);

		#retrieve evidence and count no of types
		my ($utr_ids,$cds_ids,$other_ids);
		my $trans_evi = $e->{$tsi}{'evidence'};
		my $extra_evi = $e->{$tsi}{'extra_evidence'};
		my $row_c;
		if ($trans_evi) {
			$row_c++ if ($utr_ids = $trans_evi->{'UTR'});
			$row_c++ if ($cds_ids = $trans_evi->{'CDS'});
			$row_c++ if ($other_ids = $trans_evi->{'UNKNOWN'});
		}
		else { $row_c++; }
		$row_c++ if $extra_evi;
			
		my $url = $self->object->_url({
			'type'   => 'Transcript',
			'action' => 'Evidence',
			't'      => $tsi,
		});
		
		$html .= $row_c ? "<td class=\"bg2\"  rowspan=$row_c>" : "<td>";
		$html .= "<a href=\"$url\">$tsi</a></td>";
		if ($trans_evi) {
			if ($cds_ids) {
				my $links = $object->add_evidence_links($cds_ids);
				$html .= qq(<td>Translation support:</td><td>$links</td>);
				my $txt = join q{, }, sort(keys %$cds_ids);
				$html .= qq(<td>$txt</td>);
				$html .= qq(</tr><tr>);
			}
			if ($utr_ids) {
				my $links = $object->add_evidence_links($utr_ids);
				$html .= qq(<td>UTR support:</td><td>$links</td>);
				my $txt = join q{, }, sort(keys %$utr_ids);
				$html .= qq(<td>$txt</td>);
				$html .= qq(</tr><tr>);
			}
			if ($other_ids) { 
				my $links = $object->add_evidence_links($other_ids);
				$html .= qq(<td>Other support:</td><td>$links</td>);
				my $txt = join q{, }, sort(keys %$other_ids);
				$html .= qq(<td>$txt</td>);
				$html .= qq(</tr><tr>);
			}
		}
		else {
			$html .= qq(<td colspan=3>No evidence stored for the transcript</td></tr><tr>);
		}
		if ($extra_evi) {
			my $c = scalar(keys(%$extra_evi));
			$html .= "<td colspan=3>Exons are further supported by another <a href=\"$url\">$c features</a></td></tr><tr>";
		}

		unless ($trans_evi || $extra_evi) {
			$html .= qq(<td>No supporting evidence available for this gene</td></tr>);
		}
		$html .= "</td></tr>";
	}		
	$html .=  "</table>";
	return $html;
}


1;


