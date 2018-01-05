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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score

=head1 DESCRIPTION

	Uses perl DBI to query the 'ortholog_quality_metric' table in the pipeline database 
	there are two percentage scores for each homolog
	the max percentage score is recorded and branched to a new table called 'ortholog_metric'


    Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score  -goc_mlss_id <100021> -compara_db <DB_url>

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my $self = shift;
	my $mlss_id = $self->param_required('goc_mlss_id');

	print "Start of  Ortholog_max_score   1111111111111 mlss id --------------------  :  $mlss_id  111111111111111111111111111111\n\n" if ( $self->debug );

	my $query = "SELECT homology_id, goc_score, method_link_species_set_id FROM ortholog_goc_metric where method_link_species_set_id = $mlss_id";
	my $quality_data = $self->compara_dba->dbc->db_handle->selectall_arrayref($query, {});
	$self->param('quality_data', $quality_data);

	
	print Dumper($quality_data) if ( $self->debug >3);
	
}

sub run {
	my $self = shift;
	my $homology_adaptor  = $self->compara_dba->get_HomologyAdaptor;
	my $orth_results = {};
	while (my $result =shift @{ $self->param('quality_data')}) {

		if (exists($orth_results->{$result->[0]})) {
			#grab the one with the higher percent score

			#this if is for the scaffolds that only contain one gene, hence the result is null
			#this is no longer neeeded since we are throwing out scaffolds that contain only a single gene from the very start.
			print $orth_results->{$result->[0]} , "   ", $result->[1], "\n\n" if ( $self->debug >3 );

			$orth_results->{$result->[0]} = $orth_results->{$result->[0]} >= $result->[1] ? $orth_results->{$result->[0]} : $result->[1] ; 

			# ***** ONLY DATAFLOWING FOR THE TESTING PURPOSES!!!
			#			$self->dataflow_output_id( {'method_link_species_set_id' => $self->param_required('goc_mlss_id'), 'homology_id' => $result->[0], 'goc_score' => $orth_results->{$result->[0]} }, 2 );

			print "Updating homology table goc score\n" if ( $self->debug );

			print $orth_results->{$result->[0]}, "  GOC score \n Homology id   ", $result->[0], "\n result mlss id :  ", 
				$result->[2], "\n goc mlss id ------- \n", $self->param_required('goc_mlss_id'), "\n\n" if ( $self->debug );
			$homology_adaptor->update_goc_score($result->[0], $orth_results->{$result->[0]});
			delete $orth_results->{$result->[0]}; #get rid of all the homologies with 2 goc scores
		} 
		else {
			$orth_results->{$result->[0]} = $result->[1];
		}
	} 

	print "\n what is left now are the homology_ids that have 1 goc score. This are one to many homologs where 
		the one does not have a goc score because it was the only gene on its chromosome so the goc score will be NULL\n\n";
	print Dumper($orth_results) if ( $self->debug > 3);

	foreach my $key ( keys %{$orth_results} ) {
		$homology_adaptor->update_goc_score($key, $orth_results->{$key});
	}
	
	print "\n\n mlss id -- :  ",$self->param_required('goc_mlss_id')," 11111111111111 \n goc threshold  \n", $self->param('goc_threshold'), "\n\n" if ( $self->debug );
}


1;
