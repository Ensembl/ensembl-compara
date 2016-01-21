=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score

=head1 SYNOPSIS

=head1 DESCRIPTION
	Uses perl DBI to query the 'ortholog_quality_metric' table in the pipeline database 
	there are two percentage scores for each homolog
	the max percentage score is recorded and branched to a new table called 'ortholog_metric'


    Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score  -mlss_ID <100021> -db_conn <DB_url>

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;


sub fetch_input {
	my $self = shift;
	my $mlss_ID = $self->param_required('mlss_ID');
	my $query = "SELECT homology_id, goc_score, method_link_species_set_id FROM ortholog_goc_metric where method_link_species_set_id = $mlss_ID ORDER BY homology_id";
	my $quality_data = $self->data_dbc->db_handle->selectall_arrayref($query, {});
	$self->param('quality_data', $quality_data);
#	print Dumper($quality_data);
}

sub run {
	my $self = shift;
	my $homology_adaptor  = $self->compara_dba->get_HomologyAdaptor;
	my $orth_results = {};
	while (my $result =shift @{ $self->param('quality_data')}) {
#		print $result->[0], "  ", $result->[1], "\n";

		if (defined($orth_results->{$result->[0]})) {

			#grab the one with the higher percent score

			$orth_results->{$result->[0]} = $orth_results->{$result->[0]} >= $result->[1] ? $orth_results->{$result->[0]} : $result->[1] ; 

#			print "method_link_species_set_id ", $self->param_required('mlss_ID'), ' homology_id ' , $result->[0], ' percent_conserved_score ' , $orth_results->{$result->[0]}, " \n\n";
#			$self->dataflow_output_id( {'method_link_species_set_id' => $self->param_required('mlss_ID'), 'homology_id' => $result->[0], 'goc_score' => $orth_results->{$result->[0]} }, 2 );

			print "Updating homology table goc score\n" if ( $self->debug );
			my $homology = $homology_adaptor->fetch_by_dbID($result->[0]);
			$homology->goc_score($orth_results->{$result->[0]});
			
			$homology_adaptor->update_goc_score($homology);
		} else {
			$orth_results->{$result->[0]} = $result->[1];
		}
	} 

#	print Dumper($orth_results);
}
1;
