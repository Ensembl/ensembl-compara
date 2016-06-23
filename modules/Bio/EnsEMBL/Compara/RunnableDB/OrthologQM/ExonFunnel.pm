package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::ExonFunnel;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub write_output {
	my $self = shift;

	$self->dataflow_output_id( $self->param('genome_db_pairs'), 1 ); # to prepare_mlss
}

1;