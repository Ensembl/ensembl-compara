=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut



=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::RemoveAnchorOverlaps

=cut

=head1 SYNOPSIS

parameters
{input_analysis_id=> ?,method_link_species_set_id=> ?,input_method_link_species_set_id=> ?, genome_db_ids => [?],}

=cut

=head1 DESCRIPTION

Removes the minimum number of overlappping anchors.

=cut

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::RemoveAnchorOverlaps;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Utils::Exception qw(throw);


use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
	return {
		'overlapping_id' => 3333, # unique id for overlapping anchors
	};
}

sub run {
	my ($self) = @_;
	my $anc_mapping_mlssid = $self->param('mapping_mlssid');
	my $anchor_align_adaptor = $self->compara_dba()->get_adaptor("AnchorAlign");
	my $dnafrag_ids = $anchor_align_adaptor->fetch_all_dnafrag_ids($anc_mapping_mlssid);
	my (%Overlappping_anchors, %Anchors_2_remove, %Scores);
	foreach my $genome_db_id(sort keys %{$dnafrag_ids}) {
		my %genome_db_dnafrags;
		foreach my $genome_db_anchors(@{ $anchor_align_adaptor->fetch_all_anchors_by_genome_db_id_and_mlssid(
						$genome_db_id, $anc_mapping_mlssid) }) {
			push(@{ $genome_db_dnafrags{ $genome_db_anchors->[0] } }, [ @{ $genome_db_anchors }[1..4] ]);	
		}
		foreach my $dnafrag_id(sort keys %genome_db_dnafrags) {
			my @Dnafrag_anchors = @{ $genome_db_dnafrags{$dnafrag_id} };
			for(my$i=0;$i<@Dnafrag_anchors-1;$i++) { #count number of overlaps an anchor has at every position to which it maps
				for(my$j=$i+1;$j<@Dnafrag_anchors;$j++) {
					if($Dnafrag_anchors[$i]->[3] >= $Dnafrag_anchors[$j]->[2]) {
						$Overlappping_anchors{$Dnafrag_anchors[$i]->[1]}{$Dnafrag_anchors[$j]->[1]}++;
						$Overlappping_anchors{$Dnafrag_anchors[$j]->[1]}{$Dnafrag_anchors[$i]->[1]}++;
					}
					else {
						splice(@Dnafrag_anchors, $i, 1);
						$i--;
						last;
					}
				}
			}
		}
	}
	foreach my$anchor(sort keys %Overlappping_anchors) {
		foreach my $overlapping_anchor(sort keys %{$Overlappping_anchors{$anchor}}) {
			$Scores{$anchor} += ($Overlappping_anchors{$anchor}{$overlapping_anchor})**2; #score the anchors according to the number of overlaps
		}
	}
	print STDERR "scores: ", scalar(keys %Scores), "\n";
	my$flag = 1;
	while($flag) {
		$flag = 0;
		foreach my $anchor(sort {$Scores{$b} <=> $Scores{$a}} keys %Scores) { #get highest scoring anchor
			next unless(exists($Scores{$anchor})); #don't add it to "remove list" if it's already gone from the score hash 
			foreach my $anc_with_overlap_2_anchor(sort keys %{$Overlappping_anchors{$anchor}}) { #find all the anchors which overlap this anchor 
				$Scores{$anc_with_overlap_2_anchor} -= ($Overlappping_anchors{$anc_with_overlap_2_anchor}{$anchor})**2; #decrement the score
				delete $Scores{$anc_with_overlap_2_anchor} unless($Scores{$anc_with_overlap_2_anchor});
				#if score is zero remove this anchor from the overlapping list, 
				delete($Overlappping_anchors{$anc_with_overlap_2_anchor}{$anchor}); #remove high scoring anchor from hash of overlaps
			}
			delete($Overlappping_anchors{$anchor}); #remove high scoring anchor from hash 
			delete($Scores{$anchor}); #also remove it from scoring hash
			$Anchors_2_remove{$anchor}++; #add it to list of ancs to remove
		}
		$flag = 1  if (scalar(keys %Scores));
	}
	print STDERR "anchors to remove: ", scalar(keys %Anchors_2_remove), "\n";
	$self->param('overlapping_ancs_to_remove', [keys %Anchors_2_remove]);
	return 1;
}


sub write_output {
	my ($self) = @_;
	my $anchor_align_adaptor = $self->compara_dba()->get_adaptor("AnchorAlign");
	my $Anchors_2_remove = $self->param('overlapping_ancs_to_remove'); 
	$anchor_align_adaptor->update_anchor_status($Anchors_2_remove, $self->param('overlapping_id'), $self->param('mapping_mlssid'));
}

1;

