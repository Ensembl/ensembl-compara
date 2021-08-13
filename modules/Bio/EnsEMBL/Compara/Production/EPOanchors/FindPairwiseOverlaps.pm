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

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::FindPairwiseOverlaps;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
	

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;
	# $compara_pairwise_dba is the pairwise alignments db
	my $compara_pairwise_dba = $self->get_cached_compara_dba('compara_pairwise_db');
	$self->param('compara_pairwise_dba', $compara_pairwise_dba);
	my $reference_genome_db_name = $self->param_required('reference_genome_db_name');
	my $ref_genome_db = $self->compara_dba->get_GenomedbAdaptor()->fetch_by_name_assembly($reference_genome_db_name);
	# $reference_species_dba is the reference species core dba object
	my $reference_species_dba = $ref_genome_db->db_adaptor;
	$self->param('reference_dba', $reference_species_dba);
        
	$self->param('ref_genome_db', $ref_genome_db);
	my $ref_slice_adaptor = $reference_species_dba->get_SliceAdaptor();
	my $ref_dnafrag = $self->compara_dba->get_DnaFragAdaptor()->fetch_by_dbID($self->param('ref_dnafrag_id'));
	$self->param('ref_dnafrag', $ref_dnafrag);
	$self->param('dnafrag_chunks', eval{ $self->param('dnafrag_chunks') });
	my $genomic_align_block_adaptor = $compara_pairwise_dba->get_GenomicAlignBlockAdaptor;
	my $method_link_species_set_adaptor = $compara_pairwise_dba->get_MethodLinkSpeciesSetAdaptor;
	my $ref_slice = $ref_slice_adaptor->fetch_by_region($ref_dnafrag->coord_system_name,
				$ref_dnafrag->name, @{ $self->param('dnafrag_chunks') });
	$self->param('ref_slice_adaptor', $ref_slice_adaptor);
	my (@multi_gab_overlaps, @mlss);
        my $methods = $compara_pairwise_dba->get_MethodAdaptor->fetch_all_by_class_pattern('GenomicAlignBlock.pairwise_alignment');
        my $main_mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param_required('mlss_id'));
        $self->disconnect_from_databases;
        my @non_ref_genome_db_list;
        foreach my $gdb (@{$main_mlss->species_set->genome_dbs}){
            my $principal = $gdb->principal_genome_db();
            if (defined $principal) {
                push (@non_ref_genome_db_list, $principal);
            }
            else {
                push (@non_ref_genome_db_list, $gdb);
            }
        }
        foreach my $non_ref_genome_db (@non_ref_genome_db_list) {
                next if $non_ref_genome_db->dbID == $ref_genome_db->dbID;
                my $species_set = $compara_pairwise_dba->get_SpeciesSetAdaptor->fetch_by_GenomeDBs( [$ref_genome_db, $non_ref_genome_db] )
                    || die "Cannot find a SpeciesSet for the pair ".$ref_genome_db->toString." + ".$non_ref_genome_db->toString."\n";
                my @pair_mlss = grep {defined $_} map {$method_link_species_set_adaptor->fetch_by_method_link_id_species_set_id($_->dbID, $species_set->dbID)} @$methods;
                die "No pairwise alignment could be found for the pair ".$ref_genome_db->toString." + ".$non_ref_genome_db->toString."\n" unless @pair_mlss;
                die "Several pairwise alignments available for the pair ".$ref_genome_db->toString." + ".$non_ref_genome_db->toString."\n" if scalar(@pair_mlss) > 1;
                my $mlss = $pair_mlss[0];
		my $gabs = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $ref_slice);
		foreach my $genomic_align_block( @{ $gabs } ){
			my $restricted_gab = $genomic_align_block->restrict_between_reference_positions( @{ $self->param('dnafrag_chunks') } );
			my $rgab_len;
			eval{ $rgab_len = $restricted_gab->length };
			if($@){
				$self->warning($@);
				last;
			}

			next if $rgab_len < $self->param('min_anchor_size');
				push( @multi_gab_overlaps, [
					$restricted_gab->reference_genomic_align->dnafrag_start,
					$restricted_gab->reference_genomic_align->dnafrag_end,
					$non_ref_genome_db->dbID ] );
		}	
		push(@mlss, $mlss);
	}
	$self->param('mlss', \@mlss);
	# @multi_genomic_align_blocks is a list of [ref_dnafrag_start,ref_dnafrag_end,nonref-species-id] 
	# for each genomic_align_block associated with the reference dnafrag (and the particular method_link_species_set_id(s))	
	$self->param('overlapping_gabs', [ sort {$a->[0] <=> $b->[0]} @multi_gab_overlaps ]);
}

sub run {
	my ($self) = @_;
	my($overlap_index_ranges, $reference_positions, $genomic_aligns_on_ref_slice, $synteny_region_jobs) = 
	([],[],[],[]);
	my $max_size_diff = $self->param('max_frag_diff');
	my $overlapping_gabs = $self->param('overlapping_gabs');
	for(my$i=0;$i<@{ $overlapping_gabs }-1;$i++) { # find the overlapping gabs for a ref-dnafrag chunk 
		my $temp_end = $overlapping_gabs->[$i]->[1];
		for(my$j=$i+1;$j<@{ $overlapping_gabs };$j++) {	
			if($temp_end >= $overlapping_gabs->[$j]->[0]) {
				$temp_end = $temp_end > $overlapping_gabs->[$j]->[1] ? $temp_end : $overlapping_gabs->[$j]->[1];
			}
			else {
				push(@$overlap_index_ranges, [$i, --$j]); 
				# @$overlaps_index_ranges contains the index ranges for overlapping gabs within the chunk
				$i = $j;
				last;
			}
		}
	}
	return unless( @$overlap_index_ranges);
	for(my$k=0;$k<@$overlap_index_ranges;$k++) {
		my(%bases, @bases);
		for(my$l=$overlap_index_ranges->[$k]->[0];$l<=$overlap_index_ranges->[$k]->[1];$l++) { 
		# loop through the index positions for $overlapping_gabs
			for(my$m=$overlapping_gabs->[$l]->[0];$m<=$overlapping_gabs->[$l]->[1];$m++) {
				$bases{$m}{$overlapping_gabs->[$l]->[2]}++; 
				#count the number of non_ref org hits per base
			}
		}
		# Need at lest two sequences to make an alignment
		@bases = grep {scalar(keys %{$bases{$_}}) >= 2} sort {$a <=> $b} keys %bases;
		if(@bases){
			if( $bases[-1] - $bases[0] + 1 >= $self->param('min_anchor_size') ){
				# $reference_positions holds the regions of the ref genome which have at least 2 sequences and whose span is >= min_anchor_size
				push( @$reference_positions, [ $bases[0], $bases[-1] ] ); 
			}
		}
	}
	my $genomic_align_block_adaptor = $self->param('compara_pairwise_dba')->get_GenomicAlignBlockAdaptor;
	foreach my $coord_pair( @$reference_positions ){
		my $ref_sub_slice =  $self->param('ref_slice_adaptor')->fetch_by_region(
					$self->param('ref_dnafrag')->coord_system_name,
					$self->param('ref_dnafrag')->name,
					@$coord_pair);
		# get a unique id for the synteny_region
		my $sth = $self->dbc->prepare("INSERT INTO synteny_region (method_link_species_set_id) VALUES (?)");
		$sth->execute( $self->param('mlss_id') );
		my $synteny_region_id = $self->dbc->db_handle->last_insert_id(undef, undef, 'synteny_region', 'synteny_region_id');
		push @$synteny_region_jobs, { 'synteny_region_id' => $synteny_region_id };
		foreach my $mlss( @{ $self->param('mlss') } ){
			my $gabs = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $ref_sub_slice);
			next unless(scalar(@$gabs));
			my %non_ref_dnafrags;
			foreach my $gab(@$gabs){
				my $rgab = $gab->restrict_between_reference_positions( @$coord_pair );
				my $restricted_non_reference_genomic_aligns;
				eval{ $restricted_non_reference_genomic_aligns = $rgab->get_all_non_reference_genomic_aligns };
				if($@){
					$self->warning($@);
					last;
				}
				my $temp_start = 0;
				foreach my $non_ref_genomic_align (@$restricted_non_reference_genomic_aligns) {
					my $non_ref_dnafrag = $non_ref_genomic_align->dnafrag;
					my $uniq_id = join(":", $non_ref_dnafrag->dbID, $non_ref_genomic_align->dnafrag_strand);	
					# get the dnafrag start and end coords for all the non_ref genomic_aligns 
					# which have the same dnafrag_id and strand direction
					push(@{ $non_ref_dnafrags{ $uniq_id } }, [ $non_ref_genomic_align->dnafrag_start,
									$non_ref_genomic_align->dnafrag_end ]);
				}
			}
			foreach my $uniq_key(keys %non_ref_dnafrags){
				$non_ref_dnafrags{$uniq_key} = [ sort {$a->[0] <=> $b->[0]} @{ $non_ref_dnafrags{$uniq_key} } ];
				my ($non_ref_dnafrag_id, $non_ref_strand) = split(":", $uniq_key);
				my ($nr_start, $nr_end) = ( @{ $non_ref_dnafrags{$uniq_key} }[0]->[0], @{ $non_ref_dnafrags{$uniq_key} }[-1]->[1] );
				# if the difference of the start and end positions of the first and last non-ref frags is much greater ($max_size_diff)
				# than the length of the ref frag then they should be split into there component frags
				if($nr_end - $nr_start > ($coord_pair->[1] - $coord_pair->[0] ) * $max_size_diff) {
					foreach my $aligned_frag(@{ $non_ref_dnafrags{$uniq_key} }){
						next if ($aligned_frag->[1] - $aligned_frag->[0] > ($coord_pair->[1] - $coord_pair->[0] ) * $max_size_diff); 
						push( @$genomic_aligns_on_ref_slice, {
							synteny_region_id => $synteny_region_id,	
							dnafrag_id        => $non_ref_dnafrag_id,
							dnafrag_start     => $aligned_frag->[0],
							dnafrag_end       => $aligned_frag->[1],
							dnafrag_strand    => $non_ref_strand,
						});
					}
				}
				else {
					push( @$genomic_aligns_on_ref_slice, {
						synteny_region_id => $synteny_region_id,
						dnafrag_id        => $non_ref_dnafrag_id,
						dnafrag_start     => $nr_start,
						dnafrag_end       => $nr_end,
						dnafrag_strand    => $non_ref_strand,
					});
				}
			}
		}
		# push on the reference 
		if(scalar(@$genomic_aligns_on_ref_slice)){
			push( @$genomic_aligns_on_ref_slice, {
				synteny_region_id => $synteny_region_id,
				dnafrag_id        => $self->param('ref_dnafrag_id'),
				dnafrag_start     => $coord_pair->[0],
				dnafrag_end       => $coord_pair->[1],
				dnafrag_strand    => $ref_sub_slice->strand,
				} );	
		}
	}
	$self->param('synteny_region_jobs', $synteny_region_jobs);
	$self->param('genomic_aligns_on_ref_slice', $genomic_aligns_on_ref_slice);
}	

sub write_output {
	my ($self) = @_;
	return unless $self->param('synteny_region_jobs');
	$self->dataflow_output_id( $self->param('synteny_region_jobs'), 2);
	$self->dataflow_output_id( $self->param('genomic_aligns_on_ref_slice'), 3);
}

1;

