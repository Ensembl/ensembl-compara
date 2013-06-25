package Bio::EnsEMBL::Compara::Production::EPOanchors::ChunkRefDnaFragsFactory;

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

	my $mlss_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");	
	my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");
	my $dnafrag_adaptor = $compara_dba->get_adaptor("DnaFrag");	

	my $reference_genome_db = $genome_db_adaptor->fetch_by_dbID($reference_species_id);
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
}

sub write_output {
	my ($self) = @_;
	$self->dataflow_output_id( $self->param('dnafrag_region_jobs'), 2 );
}

1;

