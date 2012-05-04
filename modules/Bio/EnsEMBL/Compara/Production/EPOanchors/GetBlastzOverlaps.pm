#Ensembl module for Bio::EnsEMBL::Compara::Production::EPOanchors::GetBlastzOverlaps
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors:GetBlastzOverlaps:

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->run();
$exonate_anchors->write_output(); writes to database

=head1 DESCRIPTION

Given a database with anchor sequences and a target genome. This modules exonerates 
the anchors against the target genome. The required information (anchor batch size,
target genome file, exonerate parameters are provided by the analysis, analysis_job 
and analysis_data tables  

This modules is part of the Ensembl project http://www.ensembl.org

Email compara@ebi.ac.uk

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
dev@ensembl.org


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::GetBlastzOverlaps;

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Analysis;

Bio::EnsEMBL::Registry->load_all;
Bio::EnsEMBL::Registry->no_version_check(1);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;

	$self->param('ref_dnafrag_strand', 1); #reference strand is always 1 
	$self->compara_dba->dbc->disconnect_if_idle();

	my $mlssid_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
	my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor();
	my $genomic_align_block_adaptor = $self->compara_dba->get_GenomicAlignBlockAdaptor();
	$self->param('genomic_align_block_adaptor', $genomic_align_block_adaptor );
	my $dnafrag_adaptor = $self->compara_dba->get_DNAFragAdaptor();

	my $analysis_data_adaptor = $self->db->get_AnalysisDataAdaptor();
	$self->param('analysis_data', eval $analysis_data_adaptor->fetch_by_dbID($self->param('analysis_data_id') ) );

	$self->param('reference_genome_db', $genome_db_adaptor->fetch_by_dbID($self->param('genome_db_ids')->[0]) );
	$self->param('ref_dnafrag', $dnafrag_adaptor->fetch_by_dbID($self->param('ref_dnafrag_id')) );
	my (@ref_dnafrag_coords, @mlssid_adaptors, $chunk_from, $chunk_to);
	for(my$i=1;$i<@{$self->param('genome_db_ids')};$i++){ #$self->param('genome_db_ids')->[0] is the reference genome_db_id
		my $mlss_id = $mlssid_adaptor->fetch_by_method_link_type_GenomeDBs(
				$self->param('method_type'), 
				[ 
					$self->param('reference_genome_db'),
					$genome_db_adaptor->fetch_by_dbID( $self->param('genome_db_ids')->[$i] ),
				] );
		push(@mlssid_adaptors, $mlss_id);
		my $gabs = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag( 
						$mlss_id, $self->param('ref_dnafrag'), $self->param('dnafrag_chunks')->[0], $self->param('dnafrag_chunks')->[1] );
		foreach my $genomic_align_block( @$gabs ) {
			next if $genomic_align_block->length < $self->param('analysis_data')->{min_anc_size};
			push( @ref_dnafrag_coords, [ $genomic_align_block->reference_genomic_align->dnafrag_start,
					$genomic_align_block->reference_genomic_align->dnafrag_end,
					$self->param('genome_db_ids')->[$i] ] );
		}
	}				
	$self->param('mlssids', \@mlssid_adaptors );
	$self->param('ref_dnafrag_coords', [ sort {$a->[0] <=> $b->[0]} @ref_dnafrag_coords ] ); #sort reference genomic_align_blocks (gabs) by start position
	print "INPUT: ", scalar(@ref_dnafrag_coords), "\n"; 
}

sub run {
	my ($self) = @_;
	my(@dnafrag_overlaps, @ref_coords_to_gerp);
	for(my$i=0;$i<@{$self->param('ref_dnafrag_coords')}-1;$i++) { #find overlapping gabs in reference seq coords
		my $temp_end = $self->param('ref_dnafrag_coords')->[$i]->[1];
		for(my$j=$i+1;$j<@{$self->param('ref_dnafrag_coords')};$j++) {
			if($temp_end >= $self->param('ref_dnafrag_coords')->[$j]->[0]) {
				$temp_end = $temp_end > $self->param('ref_dnafrag_coords')->[$j]->[1] ? $temp_end : $self->param('ref_dnafrag_coords')->[$j]->[1];
			}
			else {
				push(@dnafrag_overlaps, [$i, --$j]);
				$i = $j;
				last;
			}
		}
	}
	for(my$k=0;$k<@dnafrag_overlaps;$k++) {
		my(%bases, @bases);
		for(my$l=$dnafrag_overlaps[$k]->[0];$l<=$dnafrag_overlaps[$k]->[1];$l++) {#indices for $self->param('ref_dnafrag_coords')
			for(my$m=$self->param('ref_dnafrag_coords')->[$l]->[0];$m<=$self->param('ref_dnafrag_coords')->[$l]->[1];$m++) {
				$bases{$m}{$self->param('ref_dnafrag_coords')->[$l]->[2]}++; #count the number of non_ref org hits per base
			}
		}
		foreach my $base(sort {$a <=> $b} keys %bases) {
			if((keys %{$bases{$base}}) >= $self->param('analysis_data')->{min_number_of_org_hits_per_base}) {
				push(@bases, $base);
			}
		}
		if(@bases) {
			if($bases[-1] - $bases[0] >= $self->param('analysis_data')->{min_anc_size}) {
				push(@ref_coords_to_gerp, [ $bases[0], $bases[-1] ]);
			}
		}
	}
	my (%genomic_aligns_on_ref_slice);
	my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($self->param('reference_genome_db')->name, "core", "Slice");
	foreach my $coord_pair(@ref_coords_to_gerp) {
		my $ref_slice = $query_slice_adaptor->fetch_by_region( 
			$self->param('ref_dnafrag')->coord_system_name, $self->param('ref_dnafrag')->name, $coord_pair->[0], $coord_pair->[1] );
		foreach my $mlss_id(@{$self->param('mlssids')}) {			
			my $gabs = $self->param('genomic_align_block_adaptor')->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss_id, $ref_slice);
			foreach my $gab (@$gabs) {
				my $rgab = $gab->restrict_between_reference_positions($coord_pair->[0], $coord_pair->[1]);
				my $restricted_non_reference_genomic_aligns = $rgab->get_all_non_reference_genomic_aligns;
				foreach my $genomic_align (@$restricted_non_reference_genomic_aligns) {
					push(@{ $genomic_aligns_on_ref_slice{"$coord_pair->[0]-$coord_pair->[1]"}{$genomic_align->dnafrag->dbID}{$genomic_align->dnafrag_strand} },
						[ $genomic_align->dnafrag_start, $genomic_align->dnafrag_end ]);
				}
			}
		}
		foreach my $reference_from_to(sort keys %genomic_aligns_on_ref_slice) {
			foreach my $dnafrag_id(sort keys %{$genomic_aligns_on_ref_slice{$reference_from_to}}) {
				foreach my $dnafrag_strand(sort keys %{$genomic_aligns_on_ref_slice{$reference_from_to}{$dnafrag_id}}) {
					my $sorted = \@{$genomic_aligns_on_ref_slice{$reference_from_to}{$dnafrag_id}{$dnafrag_strand}};
					@{$sorted} = sort { $a->[0] <=> $b->[0] } @{$sorted};
				}
			}
		}
	}
	$self->param('genomic_aligns_on_ref_slice', \%genomic_aligns_on_ref_slice );
	print "RUN: ", scalar(keys %genomic_aligns_on_ref_slice), "\n";
}

sub write_output {
	my ($self) = @_;
	my %sql_statements = (
		insert_synteny_region => "INSERT INTO synteny_region (method_link_species_set_id) VALUES (?)",
		insert_dnafrag_region => "INSERT INTO dnafrag_region (synteny_region_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand) VALUES (?,?,?,?,?)",
		insert_next_analysis_job => "INSERT INTO analysis_job (analysis_id, input_id) VALUES (?,?)",
		select_max_synteny_region_id => "SELECT MAX(synteny_region_id) FROM synteny_region WHERE method_link_species_set_id = ?", 
		select_logic_name => "SELECT logic_name FROM analysis WHERE analysis_id = ?",
		select_next_analysis_id => "SELECT ctrled_analysis_id FROM analysis_ctrl_rule WHERE condition_analysis_url = (SELECT logic_name FROM analysis WHERE analysis_id = ?)",
		select_next_mlssid => "SELECT method_link_species_set_id FROM method_link_species_set WHERE name = (SELECT logic_name FROM analysis WHERE analysis_id = ?)",
		select_species_set_id => "SELECT species_set_id FROM method_link_species_set WHERE method_link_species_set_id = ?",
		select_genome_db_ids => "SELECT GROUP_CONCAT(genome_db_id) FROM species_set WHERE species_set_id = ?",
	);
	foreach my$sql_statement(keys %sql_statements) {#prepare all the sql statements
	       	$sql_statements{$sql_statement} = $self->compara_dba->dbc->prepare($sql_statements{$sql_statement});
	}
	my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($self->param('reference_genome_db')->name, "core", "Slice");
	eval {
		$sql_statements{select_next_analysis_id}->execute( $self->param('analysis_id') ) or die;
	};
	if($@) {
		die $@;
	}
	my $next_analysis_id = ($sql_statements{select_next_analysis_id}->fetchrow_array)[0];
	$sql_statements{select_next_mlssid}->execute( $next_analysis_id );
	my $next_method_link_species_set_id = ($sql_statements{select_next_mlssid}->fetchrow_array)[0];
	$sql_statements{select_species_set_id}->execute( $next_method_link_species_set_id );
	$sql_statements{select_genome_db_ids}->execute( ($sql_statements{select_species_set_id}->fetchrow_array)[0] );
	my $genome_db_ids = ($sql_statements{select_genome_db_ids}->fetchrow_array)[0];
	foreach my $ref_coords(sort keys %{$self->param('genomic_aligns_on_ref_slice')}) {
		my @Synteny_blocks_to_insert;
		my $temp_next_analysis_id = $next_analysis_id;
		my ($ref_from, $ref_to) = split("-", $ref_coords);
		push(@Synteny_blocks_to_insert, [ $self->param('ref_dnafrag')->dbID, $ref_from, $ref_to, $self->param('ref_dnafrag_strand') ]);
		foreach my $non_ref_dnafrag_id(sort keys %{$self->param('genomic_aligns_on_ref_slice')->{$ref_coords}}) {
			foreach my $non_ref_strand(sort keys %{$self->param('genomic_aligns_on_ref_slice')->{$ref_coords}->{$non_ref_dnafrag_id}}) {
				my $non_ref_coords = $self->param('genomic_aligns_on_ref_slice')->{$ref_coords}->{$non_ref_dnafrag_id}->{$non_ref_strand};
				next if ($non_ref_coords->[-1]->[1] - $non_ref_coords->[0]->[0] < $self->param('analysis_data')->{min_anc_size} || 
					($non_ref_coords->[-1]->[1] - $non_ref_coords->[0]->[0]) < ($ref_to - $ref_from) * 0.2 ||
					($non_ref_coords->[-1]->[1] - $non_ref_coords->[0]->[0]) > ($ref_to - $ref_from) * 5 ); #need to change - gets rid of unalignable rubbish 
				push(@Synteny_blocks_to_insert, [$non_ref_dnafrag_id, $non_ref_coords->[0]->[0], 
								$non_ref_coords->[-1]->[1], $non_ref_strand]);
			}
		}
		if(@Synteny_blocks_to_insert > 2) { #need at least 3 sequences for gerp
			$self->compara_dba->dbc->db_handle->do("LOCK TABLES synteny_region WRITE");
			$sql_statements{insert_synteny_region}->execute( $self->param('method_link_species_set_id') );
			$sql_statements{select_max_synteny_region_id}->execute( $self->param('method_link_species_set_id') );
			my $synteny_region_id = ($sql_statements{select_max_synteny_region_id}->fetchrow_array)[0];
			$self->compara_dba->dbc->db_handle->do("UNLOCK TABLES");
			while($temp_next_analysis_id) {
				my($input_id_string, $next_logic_name);
				$sql_statements{select_logic_name}->execute( $temp_next_analysis_id );
				$next_logic_name = ($sql_statements{select_logic_name}->fetchrow_array)[0];
				if( $next_logic_name=~/pecan/i ) {
					$input_id_string = "{ synteny_region_id=>$synteny_region_id, method_link_species_set_id=>" .
						$next_method_link_species_set_id . ", tree_analysis_data_id=>" . $self->param('tree_analysis_data_id') . ", }"; 
				}
				elsif( $next_logic_name=~/gerp/i ) {
					$input_id_string = "{genomic_align_block_id=>$synteny_region_id,species_set=>[$genome_db_ids]}";
				}
				eval { #add jobs to analysis_job for next analyses (pecan or gerp)
					$sql_statements{insert_next_analysis_job}->execute($temp_next_analysis_id, $input_id_string);
				};
				$sql_statements{select_next_analysis_id}->execute( $temp_next_analysis_id );
				$temp_next_analysis_id = ($sql_statements{select_next_analysis_id}->fetchrow_array)[0];
			}
			foreach my $dnafrag_region(@Synteny_blocks_to_insert) {
				eval { 
					$sql_statements{insert_dnafrag_region}->execute( $synteny_region_id, @{$dnafrag_region} );
				};
				if($@) {
					die $@;
				}
			}
		}
	}
	print "Genome_db_ids: $genome_db_ids\n";
}


1;

