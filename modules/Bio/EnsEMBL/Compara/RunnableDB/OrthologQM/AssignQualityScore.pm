=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore

=head1 SYNOPSIS

	Writes final score for the homology into homology.wga_coverage

=head1 DESCRIPTION

	Inputs:
	{homology_id => score}

	Outputs:
	No data is dataflowed from this runnable
	Score is written to homology table of compara_db option

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore;

use strict;
use warnings;
use Data::Dumper;
use DBI;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;

=head2 write_output

	Description: write avg score to homology table & threshold to mlss_tag

=cut

sub write_output {
	my $self = shift;

	my $homology_adaptor = $self->compara_dba->get_HomologyAdaptor;
	$homology_adaptor->update_wga_coverage($self->param_required('homology_id'), $self->param_required('wga_coverage') );

	# write threshold to mlss_tag
	
	
}

sub _calculate_threshold {
	return 50;
}

1;