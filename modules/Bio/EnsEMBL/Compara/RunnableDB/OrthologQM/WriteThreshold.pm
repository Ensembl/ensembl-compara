=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::WriteThreshold

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::WriteThreshold;

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
	my $mlss_id = $self->param('mlss');

	# write threshold to mlss_tag
	my $mlss_adap = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
	my $mlss = $mlss_adap->fetch_by_dbID( $mlss_id );
	$mlss->store_tag( 'ortholog_quality_threshold', $self->_calculate_threshold );
}

sub _calculate_threshold {
	return 50;
}

1;