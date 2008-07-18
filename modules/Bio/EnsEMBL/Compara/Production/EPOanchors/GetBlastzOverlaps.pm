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
ensembl-dev@ebi.ac.uk


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut
#
package Bio::EnsEMBL::Compara::Production::EPOanchors::GetBlastzOverlaps;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_all;
Bio::EnsEMBL::Registry->no_version_check(1);

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


sub configure_defaults {
 	my $self = shift;
	$self->ref_dnafrag_strand(1); #reference strand is always 1 
  	return 1;
}

sub fetch_input {
	my ($self) = @_;
	$self->configure_defaults();
	$self->get_parameters($self->parameters);
	#create a Compara::DBAdaptor which shares the same DBI handle with $self->db (Hive DBAdaptor)
	$self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc) or die "cant connect\n";
	$self->{'comparaDBA'}->dbc->disconnect_if_idle();
	$self->{'hiveDBA'} = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-DBCONN => $self->{'comparaDBA'}->dbc) or die "cant connect\n";
	$self->{'hiveDBA'}->dbc->disconnect_if_idle();
	my $analysis_data_adaptor = $self->{hiveDBA}->get_AnalysisDataAdaptor();
	my $mlssid_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");
	my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "GenomeDB");
	my $genomic_align_block_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "GenomicAlignBlock"); 
	$self->genomic_align_block_adaptor( $genomic_align_block_adaptor );
	my $dnafrag_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "DNAFrag");
	$self->analysis_data( eval $analysis_data_adaptor->fetch_by_dbID($self->analysis_data_id) );
	$self->get_input_id($self->input_id);
	$self->reference_genome_db( $genome_db_adaptor->fetch_by_dbID($self->genome_db_ids->[0]) );
	$self->ref_dnafrag( $dnafrag_adaptor->fetch_by_dbID($self->ref_dnafrag_id) );
	my (@ref_dnafrag_coords, @mlssid_adaptors, $chunk_from, $chunk_to);
	for(my$i=1;$i<@{$self->genome_db_ids};$i++){ #$self->genome_db_ids->[0] is the reference genome_db_id
		my $mlss_id = $mlssid_adaptor->fetch_by_method_link_type_GenomeDBs(
				$self->method_type, 
				[ 
					$self->reference_genome_db,
					$genome_db_adaptor->fetch_by_dbID( $self->genome_db_ids->[$i] ),
				] );
		push(@mlssid_adaptors, $mlss_id);
		my $gabs = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag( 
						$mlss_id, $self->ref_dnafrag, $self->dnafrag_chunks->[0], $self->dnafrag_chunks->[1] );
		foreach my $genomic_align_block( @$gabs ) {
			next if $genomic_align_block->length < $self->analysis_data->{min_anc_size};
			push( @ref_dnafrag_coords, [ $genomic_align_block->reference_genomic_align->dnafrag_start,
					$genomic_align_block->reference_genomic_align->dnafrag_end,
					$self->genome_db_ids->[$i] ] );
		}
	}				
	$self->mlssids( \@mlssid_adaptors );
	$self->ref_dnafrag_coords( [ sort {$a->[0] <=> $b->[0]} @ref_dnafrag_coords ] ); #sort reference genomic_align_blocks (gabs) by start position
	print "INPUT: ", scalar(@ref_dnafrag_coords), "\n"; 
	return 1;
}

sub run {
	my ($self) = @_;
	my(@dnafrag_overlaps, @ref_coords_to_gerp);
	for(my$i=0;$i<@{$self->ref_dnafrag_coords}-1;$i++) { #find overlapping gabs in reference seq coords
		my $temp_end = $self->ref_dnafrag_coords->[$i]->[1];
		for(my$j=$i+1;$j<@{$self->ref_dnafrag_coords};$j++) {
			if($temp_end >= $self->ref_dnafrag_coords->[$j]->[0]) {
				$temp_end = $temp_end > $self->ref_dnafrag_coords->[$j]->[1] ? $temp_end : $self->ref_dnafrag_coords->[$j]->[1];
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
		for(my$l=$dnafrag_overlaps[$k]->[0];$l<=$dnafrag_overlaps[$k]->[1];$l++) {#indices for $self->ref_dnafrag_coords
			for(my$m=$self->ref_dnafrag_coords->[$l]->[0];$m<=$self->ref_dnafrag_coords->[$l]->[1];$m++) {
				$bases{$m}{$self->ref_dnafrag_coords->[$l]->[2]}++; #count the number of non_ref org hits per base
			}
		}
		foreach my $base(sort {$a <=> $b} keys %bases) {
			if((keys %{$bases{$base}}) >= $self->analysis_data->{min_number_of_org_hits_per_base}) {
				push(@bases, $base);
			}
		}
		if(@bases) {
			if($bases[-1] - $bases[0] >= $self->analysis_data->{min_anc_size}) {
				push(@ref_coords_to_gerp, [ $bases[0], $bases[-1] ]);
			}
		}
	}
	my (%genomic_aligns_on_ref_slice);
	my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($self->reference_genome_db->name, "core", "Slice");
	foreach my $coord_pair(@ref_coords_to_gerp) {
		my $ref_slice = $query_slice_adaptor->fetch_by_region( 
			$self->ref_dnafrag->coord_system_name, $self->ref_dnafrag->name, $coord_pair->[0], $coord_pair->[1] );
		foreach my $mlss_id(@{$self->mlssids}) {			
			my $gabs = $self->genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss_id, $ref_slice);
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
	$self->genomic_aligns_on_ref_slice( \%genomic_aligns_on_ref_slice );
	print "RUN: ", scalar(keys %genomic_aligns_on_ref_slice), "\n";
	return 1;
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
	       	$sql_statements{$sql_statement} = $self->{'comparaDBA'}->dbc->prepare($sql_statements{$sql_statement});
	}
	my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($self->reference_genome_db->name, "core", "Slice");
	eval {
		$sql_statements{select_next_analysis_id}->execute( $self->analysis_id ) or die;
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
	foreach my $ref_coords(sort keys %{$self->genomic_aligns_on_ref_slice}) {
		my @Synteny_blocks_to_insert;
		my $temp_next_analysis_id = $next_analysis_id;
		my ($ref_from, $ref_to) = split("-", $ref_coords);
		push(@Synteny_blocks_to_insert, [ $self->ref_dnafrag->dbID, $ref_from, $ref_to, $self->ref_dnafrag_strand ]);
		foreach my $non_ref_dnafrag_id(sort keys %{$self->genomic_aligns_on_ref_slice->{$ref_coords}}) {
			foreach my $non_ref_strand(sort keys %{$self->genomic_aligns_on_ref_slice->{$ref_coords}->{$non_ref_dnafrag_id}}) {
				my $non_ref_coords = $self->genomic_aligns_on_ref_slice->{$ref_coords}->{$non_ref_dnafrag_id}->{$non_ref_strand};
				next if ($non_ref_coords->[-1]->[1] - $non_ref_coords->[0]->[0] < $self->analysis_data->{min_anc_size} || 
					($non_ref_coords->[-1]->[1] - $non_ref_coords->[0]->[0]) < ($ref_to - $ref_from) * 0.2 ||
					($non_ref_coords->[-1]->[1] - $non_ref_coords->[0]->[0]) > ($ref_to - $ref_from) * 5 ); #need to change - gets rid of unalignable rubbish 
				push(@Synteny_blocks_to_insert, [$non_ref_dnafrag_id, $non_ref_coords->[0]->[0], 
								$non_ref_coords->[-1]->[1], $non_ref_strand]);
			}
		}
		if(@Synteny_blocks_to_insert > 2) { #need at least 3 sequences for gerp
			$self->{'comparaDBA'}->dbc->db_handle->do("LOCK TABLES synteny_region WRITE");
			$sql_statements{insert_synteny_region}->execute( $self->method_link_species_set_id );
			$sql_statements{select_max_synteny_region_id}->execute( $self->method_link_species_set_id );
			my $synteny_region_id = ($sql_statements{select_max_synteny_region_id}->fetchrow_array)[0];
			$self->{'comparaDBA'}->dbc->db_handle->do("UNLOCK TABLES");
			while($temp_next_analysis_id) {
				my($input_id_string, $next_logic_name);
				$sql_statements{select_logic_name}->execute( $temp_next_analysis_id );
				$next_logic_name = ($sql_statements{select_logic_name}->fetchrow_array)[0];
				if( $next_logic_name=~/pecan/i ) {
					$input_id_string = "{ synteny_region_id=>$synteny_region_id, method_link_species_set_id=>" .
						$next_method_link_species_set_id . ", tree_analysis_data_id=>" . $self->tree_analysis_data_id . ", }"; 
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
	return 1;
}

sub mlssids {
	my $self = shift;
	if (@_) {
		$self->{_mlssids} = shift;
	}
	return $self->{_mlssids};
}

sub ref_dnafrag_strand {
	my $self = shift;
	if (@_) {
		$self->{_ref_dnafrag_strand} = shift;
	}
	return $self->{_ref_dnafrag_strand};
}

sub tree_analysis_data_id {
	my $self = shift;
	if (@_) {
		$self->{_tree_analysis_data_id} = shift;
	}
	return $self->{_tree_analysis_data_id};
}

sub analysis_data_id {
	my $self = shift;
	if (@_) {
		$self->{_analysis_data_id} = shift;
	}
	return $self->{_analysis_data_id};
}

sub analysis_data {
	my $self = shift;
	if (@_) {
		$self->{_analysis_data} = shift;
	}
	return $self->{_analysis_data};
}

sub analysis_id {
	my $self = shift;
	if (@_) {
		$self->{_analysis_id} = shift;
	}
	return $self->{_analysis_id};
}

sub ref_dnafrag_coords {
	my $self = shift;
	if (@_) {
		$self->{_ref_dnafrag_coords} = shift;
	}
	return $self->{_ref_dnafrag_coords};
}

sub genomic_aligns_on_ref_slice {
	my $self = shift;
	if (@_) {
		$self->{_genomic_aligns_on_ref_slice} = shift;
	}
	return $self->{_genomic_aligns_on_ref_slice};
}

sub dnafrag_overlaps {
	my $self = shift;
	if (@_) {
		$self->{_dnafrag_overlaps} = shift;
	}
	return $self->{_dnafrag_overlaps};
}

sub reference_genome_db {
	my $self = shift;
	if (@_){
		$self->{_reference_genome_db} = shift;
	}
	return $self->{_reference_genome_db};
}

sub genome_db_ids {
	my $self = shift;
	if (@_){
		$self->{_genome_db_ids} = shift;
	}
	return $self->{_genome_db_ids};
}

sub genomic_align_block_adaptor {
	my $self = shift;
	if (@_){
		$self->{_genomic_align_block_adaptor} = shift;
	}
	return $self->{_genomic_align_block_adaptor};
}

sub ref_dnafrag_id {
	my $self = shift;
	if (@_){
		$self->{_ref_dnafrag_id} = shift;
	}
	return $self->{_ref_dnafrag_id};
}

sub dnafrag_chunks {
	my $self = shift;
	if (@_){
		$self->{_dnafrag_chunks} = shift;
	}
	return $self->{_dnafrag_chunks};
}

sub ref_dnafrag {
	my $self = shift;
	if (@_){
		$self->{_ref_dnafrag} = shift;
	}
	return $self->{_ref_dnafrag};
}

sub method_type {
	my $self = shift;
	if (@_){
		$self->{_method_type} = shift;
	}
	return $self->{_method_type};
}

sub method_link_species_set_id {
	my $self = shift;
	if (@_){
		$self->{_method_link_species_set_id} = shift;
	}
	return $self->{_method_link_species_set_id};
}

sub get_parameters {
	my $self = shift;
	my $param_string = shift;
	
	return unless($param_string);
	my $params = eval($param_string);
	if(defined($params->{'analysis_data_id'})) {
		$self->analysis_data_id($params->{'analysis_data_id'});
	}
	if(defined($params->{'method_link_species_set_id'})) {
		$self->method_link_species_set_id($params->{'method_link_species_set_id'});
	}
	if(defined($params->{'tree_analysis_data_id'})) {
		$self->tree_analysis_data_id($params->{'tree_analysis_data_id'});
	}
	if(defined($params->{'analysis_id'})) {
		$self->analysis_id($params->{'analysis_id'});
	}
}

sub get_input_id {
	my $self = shift;
	my $input_id_string = shift;

	return unless($input_id_string);
	print("parsing input_id string : ",$input_id_string,"\n");
	
	my $params = eval($input_id_string);
	return unless($params);
	
	if(defined($params->{'method_type'})) {
		$self->method_type($params->{'method_type'});
	}
	if(defined($params->{'genome_db_ids'})) {
		$self->genome_db_ids($params->{'genome_db_ids'});
	}
	if(defined($params->{'ref_dnafrag_id'})) {
		$self->ref_dnafrag_id($params->{'ref_dnafrag_id'});
	}
	if(defined($params->{'dnafrag_chunks'})) {
		$self->dnafrag_chunks($params->{'dnafrag_chunks'});
	}
	return 1;
}

1;

