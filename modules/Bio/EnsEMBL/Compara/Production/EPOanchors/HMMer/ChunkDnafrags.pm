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

package Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::ChunkDnafrags;

use strict;
use warnings;
use Bio::EnsEMBL::Hive::Utils 'stringify';
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my ($self) = @_;
	my $compara_dba = $self->compara_dba();
	my @dnafrag_region_jobs = ();
	my $dnafrag_adaptor = $compara_dba->get_adaptor("DnaFrag");
	my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");
	my $dnafrag_chunk_size = $self->param('dnafrag_chunk_size');
	my $reference_species_id = $self->param('reference_genome_db_id');
	my $reference_genome_db = $genome_db_adaptor->fetch_by_dbID($reference_species_id);
	my $reference_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($reference_genome_db, undef, undef, 1);
	foreach my $dnafrag( @{ $reference_dnafrags } ){
		my $dnafrag_len = $dnafrag->length;
		if($dnafrag_len > $dnafrag_chunk_size){
			for(my$i=1;$i<=$dnafrag_len;$i+=$dnafrag_chunk_size){
				my $dnafrag_chunk_end = ($i+$dnafrag_chunk_size - 1) <= $dnafrag_len ? ($i+$dnafrag_chunk_size - 1) : $dnafrag_len;
				push @dnafrag_region_jobs, {
					'ref_dnafrag_id'	    => $dnafrag->dbID,
					'dnafrag_chunk'	    => [ $i, $dnafrag_chunk_end ],
				};
			}
		}
		else{
			push @dnafrag_region_jobs, {
				'ref_dnafrag_id'	    => $dnafrag->dbID,
				'dnafrag_chunk'	    => [ 1, $dnafrag_len ],
			};
		}
	}
	$self->param('dnafrag_region_jobs', \@dnafrag_region_jobs);
}

sub write_output {
	my ($self) = @_;
	$self->dataflow_output_id( $self->param('dnafrag_region_jobs'), 1 );
}

1;

