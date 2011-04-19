package Bio::EnsEMBL::Compara::Production::EPOanchors::ChunkRefDnafrags;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception;
use Data::Dumper;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
	my ($self) = @_;
	my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor( %{ $self->param('compara_pairwise_db') } );
	my $input_genome_db_ids = $self->param('genome_db_ids');
	my $dnafrag_chunk_size = $self->param('chunk_size');
	my $mlss_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");	
	my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");
	my $reference_species_id = $self->param('reference_genome_db_id');
	my $min_anchor_size = $self->param('min_anchor_size');
	my $reference_genome_db = $genome_db_adaptor->fetch_by_dbID($reference_species_id);
	my @method_link_types = split(":", $self->param('method_link_type'));
	my (%non_reference_genome_db_ids, %selected_genome_db_ids, @jobs);
	# find all species used in the $method_link_type(s) 
	foreach my $method_link_type ( @method_link_types ){
		my ($method_link_species_sets, $mlss);
		if( @{ $input_genome_db_ids } ){
		# if the non-reference genome_db_ids are given in the parameter list
			foreach my $non_reference_genome_db_id( @{ $input_genome_db_ids } ){
				my $non_ref_genome_db = $genome_db_adaptor->fetch_by_dbID($non_reference_genome_db_id);
				$mlss = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs(
					$method_link_type, [ $reference_genome_db, $non_ref_genome_db ]);
				if($mlss) {
					push( @{ $method_link_species_sets }, $mlss_adaptor->fetch_by_method_link_type_GenomeDBs(
							$method_link_type, [ $reference_genome_db, $non_ref_genome_db ]) ); 
				}
			}
		}
		else {	
		# else get all alignments with this method_link_type and the reference genome_db_id 
			$method_link_species_sets = $mlss_adaptor->fetch_all_by_method_link_type_GenomeDB(
							$method_link_type, $reference_genome_db);
		}
		foreach my $mlss( @{ $method_link_species_sets } ){
			foreach my $genome_db( @{ $mlss->species_set } ){
				next if ($genome_db->dbID == $reference_species_id);
				$non_reference_genome_db_ids{ $method_link_type }{ $genome_db->dbID }++;
			}
		}
	}
	foreach my $method_link_type( keys %non_reference_genome_db_ids ){ 
		$selected_genome_db_ids{ $method_link_type } = [ keys %{ $non_reference_genome_db_ids{ $method_link_type } } ];
	}
	my @chunked_reference_dnafrags;
	my $dnafrag_adaptor = $compara_dba->get_adaptor("DnaFrag");	
	my $reference_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($reference_genome_db);
	foreach my $dnafrag( @{ $reference_dnafrags } ){
		next unless($dnafrag->is_reference);
		my $dnafrag_len = $dnafrag->length;
		if($dnafrag_len > $dnafrag_chunk_size){
			for(my$i=1;$i<=$dnafrag_len;$i+=$dnafrag_chunk_size){
				my $dnafrag_chunk_end = ($i+$dnafrag_chunk_size - 1) <= $dnafrag_len ? ($i+$dnafrag_chunk_size - 1) : $dnafrag_len;
				push( @chunked_reference_dnafrags, [$dnafrag->dbID, $i, $dnafrag_chunk_end] );
			}
		}
		else{
			push( @chunked_reference_dnafrags, [$dnafrag->dbID, 1, $dnafrag_len] );
		}
	}
	foreach my $method_link_type ( sort keys %selected_genome_db_ids){
		foreach my $chunked_dnafrag( @chunked_reference_dnafrags ){
			my $job = {
				method_type => $method_link_type,
				genome_db_ids=> $selected_genome_db_ids{ $method_link_type },
				ref_dnafrag_id=> $chunked_dnafrag->[0] ,
				dnafrag_chunks=>[ $chunked_dnafrag->[1] , $chunked_dnafrag->[2] ],
			 };
			push(@jobs, $job);
		}
	}		
	$self->param('jobs', \@jobs);
}

sub run {
	my ($self) = @_;
}

sub write_output {
	my ($self) = @_;

	$self->dataflow_output_id( $self->param('jobs') , 2 );
}

1;

