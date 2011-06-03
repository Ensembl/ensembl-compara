package Bio::EnsEMBL::Compara::Production::EPOanchors::FindPairwiseOverlaps;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
	

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


sub fetch_input {
	my ($self) = @_;
	# $reference_species_dba is the reference species for the pairwise alignments
	my $reference_species_dba = new Bio::EnsEMBL::DBSQL::DBAdaptor( %{ $self->param('reference_db') } );
	# $compara_dba is the pairwise alignments db
	my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor( %{ $self->param('compara_pairwise_db') } );
	$self->param('compara_dba', $compara_dba);
	$self->param('reference_dba', $reference_species_dba);
	my $reference_genome_db_id = $self->param('reference_genome_db_id');
	my $ref_genome_db = $compara_dba->get_GenomedbAdaptor()->fetch_by_dbID($reference_genome_db_id);
	$self->param('ref_genome_db', $ref_genome_db);
	my $non_reference_genome_dbIDs = $self->param('genome_db_ids');
	my $ref_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($self->param('ref_genome_db')->name, "core", "Slice");
	my $ref_dnafrag = $compara_dba->get_DnaFragAdaptor()->fetch_by_dbID($self->param('ref_dnafrag_id'));
	$self->param('ref_dnafrag', $ref_dnafrag);
	$self->param('dnafrag_chunks', eval{ $self->param('dnafrag_chunks') });
	my $genomic_align_block_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor;
	my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
	my $ref_slice = $ref_slice_adaptor->fetch_by_region($ref_dnafrag->coord_system_name,
						$ref_dnafrag->name, @{ $self->param('dnafrag_chunks') });
	$self->param('ref_slice_adaptor', $ref_slice_adaptor);
	my (@multi_gab_overlaps, @mlss);
	my $method_type_genome_db_ids = $self->param('method_type_genome_db_ids');
	foreach my $this_method_link_type( keys %{ $method_type_genome_db_ids } ){
		foreach my $non_reference_genome_dbID( @{ $method_type_genome_db_ids->{$this_method_link_type} }){
			my $mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_genome_db_ids(
				$this_method_link_type, [ $reference_genome_db_id, $non_reference_genome_dbID ]);
			my $gabs = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
					$mlss, $ref_slice);
		
			foreach my $genomic_align_block( @{ $gabs } ){
				my $restricted_gab = $genomic_align_block->restrict_between_reference_positions( @{ $self->param('dnafrag_chunks') } );
				next if $restricted_gab->length < $self->param('min_anchor_size');
				push( @multi_gab_overlaps, [
						$restricted_gab->reference_genomic_align->dnafrag_start,
						$restricted_gab->reference_genomic_align->dnafrag_end,
						$non_reference_genome_dbID ] );
			}	
			push(@mlss, $mlss);
		}
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
		foreach my $base(sort {$a <=> $b} keys %bases) {
			if((keys %{$bases{$base}}) >= $self->param('min_number_of_org_hits_per_base')) {
				push(@bases, $base);
			}
		}	
		if(@bases){
			if( $bases[-1] - $bases[0] >= $self->param('min_anchor_size') ){
				push( @$reference_positions, [ $bases[0], $bases[-1] ] );
			}
		}
	}
	my $genomic_align_block_adaptor = $self->param('compara_dba')->get_GenomicAlignBlockAdaptor;
	my $this_method_link_species_set_id = $self->param('method_link_species_set_id');
	foreach my $coord_pair( @$reference_positions ){
		my $ref_sub_slice =  $self->param('ref_slice_adaptor')->fetch_by_region(
					$self->param('ref_dnafrag')->coord_system_name,
					$self->param('ref_dnafrag')->name,
					@$coord_pair);

		# get a unique id for the synteny_region
		my $sth = $self->dbc->prepare("INSERT INTO synteny_region (method_link_species_set_id) VALUES (?)");
		$sth->execute( $this_method_link_species_set_id );
		my $synteny_region_id = $sth->{'mysql_insertid'};
		push @$synteny_region_jobs, { 'synteny_region_id' => $synteny_region_id };

		foreach my $mlss( @{ $self->param('mlss') } ){
			my $gabs = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $ref_sub_slice);
			my %non_ref_dnafrags;
			foreach my $gab(@$gabs){
				my $rgab = $gab->restrict_between_reference_positions( @$coord_pair );
				my $restricted_non_reference_genomic_aligns = $rgab->get_all_non_reference_genomic_aligns;
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
		push( @$genomic_aligns_on_ref_slice, {
			synteny_region_id => $synteny_region_id,
			dnafrag_id        => $self->param('ref_dnafrag_id'),
			dnafrag_start     => $coord_pair->[0],
			dnafrag_end       => $coord_pair->[1],
			dnafrag_strand    => $ref_sub_slice->strand,
			} );	
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

