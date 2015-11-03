=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS

=head1 SYNOPSIS

=head1 DESCRIPTION

For two species, find a method link species set ID for an alignment between them
Try for an EPO alignment first, LASTZ if not, fail if neither are available

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

	my $species1_id = $self->param_required('species1_id');
	my $species2_id = $self->param_required('species2_id');

	# find GenomeDBs for each species
	my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;

	my $species1_gdb = $gdb_adaptor->fetch_by_dbID($species1_id);
	my $species2_gdb = $gdb_adaptor->fetch_by_dbID($species2_id);

	# allow user defined MLSS ID
	return 1 if ( defined $self->param( 'aln_mlss_id' ) );

	# try to find EPO alignments first; LASTZ if EPO not available
	my $mlss_adap = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;

	# first, check if EPO exists for complete species set
	my $species_set_name = $self->param( 'collection' );
	if ( $species_set_name ){
		my $set_mlss = $mlss_adap->fetch_by_method_link_type_species_set_name( "EPO", $species_set_name );
		if ( defined $set_mlss ) {
			$self->param( 'aln_mlss_id', $set_mlss->dbID );
			return 1;
		}
	}

	my $mlss_list_s1 = $mlss_adap->fetch_all_by_method_link_type_GenomeDB( "EPO", $species1_gdb );
	my $mlss_list_s2 = $mlss_adap->fetch_all_by_method_link_type_GenomeDB( "EPO", $species2_gdb );

	my $common_mlss = $self->_overlap( $mlss_list_s1, $mlss_list_s2 );

	if ( defined $common_mlss ){
		$self->param( 'aln_mlss_id', $common_mlss );
		$self->warning( "Using EPO alignment. mlss_id = $common_mlss" );
	}
	else {
		my $lastz = $mlss_adap->fetch_by_method_link_type_genome_db_ids( "LASTZ_NET", [ $species1_gdb->dbID, $species2_gdb->dbID ] );
		die( "Could not find any alignments between species" ) unless ( defined $lastz );
		$self->param( 'aln_mlss_id', $lastz->dbID );
		$self->warning( "Using LASTZ alignment. mlss_id = " . $lastz->dbID );
	}
}

sub write_output {
	my $self = shift;

	my $dataflow = {
		'species1_id' => $self->param( 'species1_id' ),
		'species2_id' => $self->param( 'species2_id' ),
		'aln_mlss_id' => $self->param( 'aln_mlss_id' ),
	};
	$self->dataflow_output_id( $dataflow, 1 );
}

sub _overlap {
	my ( $self, $mlss_list_s1, $mlss_list_s2 ) = @_;

	foreach my $ms1 ( @{ $mlss_list_s1 } ) {
		foreach my $ms2 ( @{ $mlss_list_s2 } ) {
			return $ms1->dbID if ( $ms1->dbID == $ms2->dbID );
		}
	}
	return;
}

1;