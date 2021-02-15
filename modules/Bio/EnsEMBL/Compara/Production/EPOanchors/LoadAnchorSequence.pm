=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 DESCRIPTION

Populates the anchor_seq table, using the "trimmed" anchors defined in the anchor_align table

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::LoadAnchorSequence;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Locus;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:insert);
use Bio::EnsEMBL::Compara::Utils::Preloader;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'max_n_proportion'  => 0.2,     # Max allowed proportion of Ns in the sequence of an anchor
    };
}

sub fetch_input {
	my ($self) = @_;
	my $trimmed_anchor_mlssid = $self->param('input_method_link_species_set_id');
	my $anchor_id = $self->param('anchor_id');
	my $anchor_align_adaptor = $self->compara_dba()->get_adaptor("AnchorAlign"); 
	my $anchor_aligns = $anchor_align_adaptor->fetch_all_by_anchor_id_and_mlss_id($anchor_id, $trimmed_anchor_mlssid);
        # Set the genome dump directory
        $self->compara_dba->get_GenomeDBAdaptor->dump_dir_location($self->param_required('genome_dumps_dir'));
        Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags($self->compara_dba->get_DnaFragAdaptor, $anchor_aligns);
	my @anchor;
	foreach my $anchor_align (@$anchor_aligns) {
            next unless $anchor_align->untrimmed_anchor_align_id;
		my($df_id,$anc_start,$anc_end,$df_strand)=($anchor_align->dnafrag_id,
							$anchor_align->dnafrag_start,
							$anchor_align->dnafrag_end,
							$anchor_align->dnafrag_strand);
		my $dnafrag = $anchor_align->dnafrag;
		my ($max_anc_seq_size, $min_anc_seq_size) = ($self->param('max_anchor_seq_len'), $self->param('min_anchor_seq_len'));
		my $mid_size = $max_anc_seq_size / 2;
		$anc_start -= $mid_size + 2;
		$anc_end += $mid_size - 2;
		$anc_start = $anc_start < 1 ? 1 : $anc_start;   # The minimum position on a DnaFrag is 1
		$anc_end = $anc_end > $dnafrag->length ? $dnafrag->length : $anc_end;    # The maximum position on a DnaFrag is its length
                my $ext_anchor = bless {
                        'dnafrag'         => $dnafrag,
                        'dnafrag_start'   => $anc_start,
                        'dnafrag_end'     => $anc_end,
                        'dnafrag_strand'  => $df_strand,
                    }, 'Bio::EnsEMBL::Compara::Locus';
                my $anc_seq = $ext_anchor->get_sequence;
		my @NS=$anc_seq=~/(N)/g;
		my $ns=join("",@NS);
		my $ratio = 0;
		if($ns){
			$ratio = length($ns)/length($anc_seq);
		}
		if($ratio < $self->param('max_n_proportion')) {
			push(@anchor, [$anchor_id, $df_id, $anc_start, $anc_end, $df_strand, $trimmed_anchor_mlssid, $anc_seq, length($anc_seq)]);
		} else {
			$self->complete_early("Anchor didn't pass the threshold: ratio=$ratio threshold=".$self->param('max_n_proportion'));
		}
	}

        my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($trimmed_anchor_mlssid);
        my $n_genomes = $mlss->species_set->size;
        if (scalar(@anchor) > $self->param_required('max_number_of_seqs_per_anchor')*$n_genomes) {
            $self->complete_early(sprintf('Not storing this anchor set because there are too many sequences (%d)', scalar(@anchor)));
        }

	$self->param('anchor', \@anchor);
}

sub write_output {
    my ($self) = @_;

    $self->compara_dba->dbc->do('DELETE FROM anchor_sequence WHERE anchor_id = ?', undef, $self->param('anchor_id'));
    bulk_insert($self->compara_dba->dbc, 'anchor_sequence', $self->param('anchor'), [qw(anchor_id dnafrag_id start end strand method_link_species_set_id sequence length)]);
}

1;



