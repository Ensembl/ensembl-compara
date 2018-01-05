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

package Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::SplitCeIds;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;
	my $compara_db = $self->compara_dba();
	Bio::EnsEMBL::Registry->load_registry_from_url( $self->param('core_db_url') );
	my $suffix = "0000000000";
	my $ce_mlssid = $self->param('mlssid_of_constrained_elements');
	my ($ce_min, $ce_max) = ($ce_mlssid . $suffix, ($ce_mlssid + 1) . $suffix);  
	my $sth = $compara_db->dbc->prepare("SELECT MIN(constrained_element_id), MAX(constrained_element_id) " .
					"FROM constrained_element WHERE constrained_element_id BETWEEN ? AND ?");
	$sth->execute($ce_min, $ce_max);
	($ce_min, $ce_max) = $sth->fetchrow_array();
	my (@ce_ids, @gdbs);
	for(my$i=$ce_min;$i<=$ce_max;$i += $self->param('ce_batch_size')){
		my $top_bound;
		if($i + $self->param('ce_batch_size') >= $ce_max){
			$top_bound = $ce_max;
		} else {
			$top_bound = $i + $self->param('ce_batch_size') - 1;
		}	
		push(@ce_ids, { 'ce_ids' => [$i, $top_bound] });
	}
	my $gdba = $compara_db->get_adaptor("GenomeDB");
	foreach my $genome( @{ $self->param_required('high_coverage_species') } ){
		my $assembly = $gdba->fetch_by_registry_name("$genome")->assembly;
		my $dbID = $gdba->fetch_by_registry_name("$genome")->dbID;
		$assembly=~s/ /_/g;
		push(@gdbs, { 'species' => $genome, 'assembly' => $assembly, 'dbID' => $dbID}); 
	}
	$self->param('constrained_element_ids', \@ce_ids);
	$self->param('repeat_genomes', \@gdbs);
	$self->param('dump_gabs_per_genome', \@gdbs);
	my $sth2 = $compara_db->dbc->prepare("SELECT DISTINCT(df.genome_db_id) FROM constrained_element ce " .
			"INNER JOIN dnafrag df ON df.dnafrag_id = ce.dnafrag_id WHERE ce.method_link_species_set_id = ?");
	$sth2->execute($ce_mlssid);
	$self->param('genome_dbs_csv', join(",", map{ $_->[0] } @{ $sth2->fetchall_arrayref() }) );
}

sub write_output {
	my ($self) = @_;
	$self->dataflow_output_id( $self->param('constrained_element_ids'), 1 );
	$self->dataflow_output_id( $self->param('repeat_genomes'), 2 );
	$self->dataflow_output_id( $self->param('dump_gabs_per_genome'), 4 );
	$self->dataflow_output_id( { 'genome_dbs_csv' => $self->param('genome_dbs_csv'), 'table' => 'genome_db' }, 3 );
	$self->dataflow_output_id( { 'genome_dbs_csv' => $self->param('genome_dbs_csv'), 'table' => 'dnafrag' }, 3 );
}

1;

