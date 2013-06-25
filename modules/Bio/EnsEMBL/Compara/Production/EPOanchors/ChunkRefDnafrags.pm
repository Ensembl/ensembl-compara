package Bio::EnsEMBL::Compara::Production::EPOanchors::ChunkRefDnafrags;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Hive::Utils 'stringify';
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my ($self) = @_;
	my $compara_dba = $self->compara_dba();

	my $dnafrag_chunk_size = $self->param('chunk_size');
	my $reference_species_id = $self->param('reference_genome_db_id');
	my $input_genome_db_ids = $self->param('genome_db_ids') || [];
	my $min_anchor_size = $self->param('min_anchor_size');
	my @method_link_types = @{$self->param('method_link_types')};

	my $mlss_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");	
	my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");
	my $dnafrag_adaptor = $compara_dba->get_adaptor("DnaFrag");	

	my $reference_genome_db = $genome_db_adaptor->fetch_by_dbID($reference_species_id);
	my %non_reference_genome_db_ids;
	# all the reference and non-reference genome_db IDs
	my @interesting_genome_db_ids = ( $reference_species_id );

	# find all species used in the $method_link_type(s) 
	foreach my $method_link_type ( @method_link_types ){
		my ($method_link_species_sets);
		if( @$input_genome_db_ids ){
		# if the non-reference genome_db_ids are given in the parameter list
			foreach my $non_reference_genome_db_id( @{ $input_genome_db_ids } ){
				my $non_ref_genome_db = $genome_db_adaptor->fetch_by_dbID($non_reference_genome_db_id);
				if(my $mlss = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs(
						$method_link_type, [ $reference_genome_db, $non_ref_genome_db ]) ) {
					push @$method_link_species_sets, $mlss;
				}
			}
		}
		else {	
		# else get all alignments with this method_link_type and the reference genome_db_id 
			$method_link_species_sets = $mlss_adaptor->fetch_all_by_method_link_type_GenomeDB(
							$method_link_type, $reference_genome_db);
		}
		foreach my $mlss( @$method_link_species_sets ) {
			foreach my $genome_db( @{ $mlss->species_set_obj->genome_dbs } ){
				next if ($genome_db->dbID == $reference_species_id);
				push(@{ $non_reference_genome_db_ids{ $method_link_type } }, $genome_db->dbID );

				push @interesting_genome_db_ids, $genome_db->dbID;
			}
		}
	}
	$self->param('method_type_genome_db_ids', { 'meta_key' => 'method_type_genome_db_ids',
						   'meta_value' => stringify(\%non_reference_genome_db_ids) });
	$self->param('species_set', { 'meta_key' => 'species_set',
					'meta_value' => stringify(\@interesting_genome_db_ids) });
	my @dnafrag_region_jobs = ();
	my $reference_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($reference_genome_db);
	foreach my $dnafrag( @{ $reference_dnafrags } ){
		next unless($dnafrag->is_reference);
		my $dnafrag_len = $dnafrag->length;
		if($dnafrag_len > $dnafrag_chunk_size){
			for(my$i=1;$i<=$dnafrag_len;$i+=$dnafrag_chunk_size){
				my $dnafrag_chunk_end = ($i+$dnafrag_chunk_size - 1) <= $dnafrag_len ? ($i+$dnafrag_chunk_size - 1) : $dnafrag_len;
				push @dnafrag_region_jobs, {
					'ref_dnafrag_id'	    => $dnafrag->dbID,
					'dnafrag_chunks'	    => [ $i, $dnafrag_chunk_end ],
				};
			}
		}
		else{
			push @dnafrag_region_jobs, {
				'ref_dnafrag_id'	    => $dnafrag->dbID,
				'dnafrag_chunks'	    => [ 1, $dnafrag_len ],
			};
		}
	}

	$self->param('dnafrag_region_jobs', \@dnafrag_region_jobs);
	$self->param('genome_dbs_csv', join(',', @interesting_genome_db_ids) );
}

sub write_output {
	my ($self) = @_;
	$self->dataflow_output_id( $self->param('dnafrag_region_jobs'), 4 );
	$self->dataflow_output_id( $self->param('method_type_genome_db_ids'), 2 );
	$self->dataflow_output_id( $self->param('species_set'), 2 );
	$self->dataflow_output_id( { 'genome_dbs_csv' => $self->param('genome_dbs_csv'), 'table' => 'genome_db' }, 3 );
	$self->dataflow_output_id( { 'genome_dbs_csv' => $self->param('genome_dbs_csv'), 'table' => 'dnafrag', },  3 );
}

1;

