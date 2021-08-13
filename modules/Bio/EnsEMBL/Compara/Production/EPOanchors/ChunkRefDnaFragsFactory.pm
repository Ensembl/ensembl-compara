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

package Bio::EnsEMBL::Compara::Production::EPOanchors::ChunkRefDnaFragsFactory;

use strict;
use warnings;
use Bio::EnsEMBL::Hive::Utils 'stringify';
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my ($self) = @_;
	my $compara_dba = $self->compara_dba();

	my $dnafrag_chunk_size = $self->param_required('chunk_size');
	my $reference_genome_db_name = $self->param_required('reference_genome_db_name');

	my $mlss_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");	
	my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");
	my $dnafrag_adaptor = $compara_dba->get_adaptor("DnaFrag");	

	my $reference_genome_db = $genome_db_adaptor->fetch_by_name_assembly($reference_genome_db_name);
	my @dnafrag_region_jobs = ();
	my $reference_dnafrags;
	if ($reference_genome_db->is_polyploid && ! defined $reference_genome_db->genome_component){
		my @frag_array;
		foreach my $gdb ( @{ $reference_genome_db->component_genome_dbs() }){
			my $_frags = $dnafrag_adaptor->fetch_all_by_GenomeDB($gdb, -IS_REFERENCE => 1); 
			push(@frag_array, @$_frags);
		}
		$reference_dnafrags = \@frag_array;
	}
	else { 
		$reference_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB($reference_genome_db, -IS_REFERENCE => 1);
	}
	foreach my $dnafrag( @{ $reference_dnafrags } ){
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

