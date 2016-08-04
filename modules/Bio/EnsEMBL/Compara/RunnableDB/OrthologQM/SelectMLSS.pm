=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS

=head1 SYNOPSIS

	For two species, find a method_link_species_set_id for an alignment between them
	Try for an EPO alignment first, LASTZ if not, fail if neither are available

=head1 DESCRIPTION

	Inputs:
	species1_id		genome_db_id from first species
	species2_id		genome_db_id from second species
	species_set_id 	id of species set which both species are members of (optional)
	aln_mlss_ids	over-ride runnable entirely by manually defining IDs

	Outputs:
	Dataflow = {species1_id => ID, species2_id => ID, aln_mlss_ids => [ID1, ID2, ID3]}

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'epo_method_link_id' => 13,
    };
}

sub fetch_input {
	my $self = shift;

	my (@aln_mlss_ids, $dba);

	my $species1_id  = $self->param_required('species1_id');
	my $species2_id  = $self->param_required('species2_id');
	my $aln_mlss_ids = $self->param( 'aln_mlss_ids' );

	if ( $self->param('alt_aln_db') ) { $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($self->param('alt_aln_db')); }
	else { $dba = $self->compara_dba }

	# find GenomeDBs for each species
	my $gdb_adaptor = $dba->get_GenomeDBAdaptor;

	my $species1_gdb = $gdb_adaptor->fetch_by_dbID($species1_id);
	my $species2_gdb = $gdb_adaptor->fetch_by_dbID($species2_id);

	# try to find EPO alignments first; LASTZ if EPO not available
	my $mlss_adap = $dba->get_MethodLinkSpeciesSetAdaptor;

	# allow user defined MLSS ID,
	# but check that mlss pertains to this set of species
	if ( defined $aln_mlss_ids ) {
		foreach my $mlss_id ( @{$aln_mlss_ids} ){
			my $this_mlss = $mlss_adap->fetch_by_dbID($mlss_id);
			die "Could not find method_link_species_set (id $mlss_id)" unless ( defined $this_mlss );
			my @mlss_gdbs = map { $_->dbID } @{ $this_mlss->species_set->genome_dbs };
			my $c = 0; # check both species are in the list
			foreach my $g ( @mlss_gdbs ) {
				$c++ if ( $g == $species1_id || $g == $species2_id );
			}
			if ( $c == 2 ) { # both species present
				push( @aln_mlss_ids, $mlss_id );
			}
		}
		if ( scalar(@aln_mlss_ids) > 0 ){
			$self->param( 'aln_mlss_ids', \@aln_mlss_ids );
			return;
		}
		else {
			# otherwise, exit runnable gracefully and don't flow
			$self->input_job->autoflow(0);
			my $exit_msg = "Given alignment mlss not relevant for species " . $species1_gdb->name . " and " . $species2_gdb->name;
			$self->complete_early($exit_msg);
		}
	}

	# first, check if EPO exists for complete species set
	# my $species_set_id = $self->param( 'species_set_id' );
	# my $common_mlss_list;
	# if ( $species_set_id ){
	# 	my $epo_method_link_id = $self->param('epo_method_link_id');
	# 	$common_mlss_list = [ $mlss_adap->fetch_by_method_link_id_species_set_id( $epo_method_link_id, $species_set_id ) ];
	# 	# if ( defined $set_mlss ) {
	# 	# 	$self->param( 'aln_mlss_ids', [$set_mlss->dbID] );
	# 	# 	return 1;
	# 	# }
	# }
	# else {

	# check if an EPO exists between both species
	my $mlss_list_s1 = $mlss_adap->fetch_all_by_method_link_type_GenomeDB( "EPO", $species1_gdb );
	my $mlss_list_s2 = $mlss_adap->fetch_all_by_method_link_type_GenomeDB( "EPO", $species2_gdb );

	my $common_mlss_list = $self->_overlap( $mlss_list_s1, $mlss_list_s2 );

	# }
	
	if ( defined $common_mlss_list ){
		foreach my $common_mlss ( @{ $common_mlss_list } ) {
			push( @aln_mlss_ids, $common_mlss->dbID );
			$self->warning( "Found EPO alignment. mlss_id = " . $common_mlss->dbID );
		}
	}
	# Last, look for a LASTZ aln between pair
	my $lastz = $mlss_adap->fetch_by_method_link_type_genome_db_ids( "LASTZ_NET", [ $species1_gdb->dbID, $species2_gdb->dbID ] );
	if ( defined $lastz ) {
		push( @aln_mlss_ids, $lastz->dbID );
		$self->warning( "Found LASTZ alignment. mlss_id = " . $lastz->dbID );
	}

	unless ( defined $lastz || defined $common_mlss_list ){
		$self->input_job->autoflow(0);
		my $exit_msg = "Could not find any alignments between species " . $species1_gdb->name . " and " . $species2_gdb->name;
		$self->complete_early($exit_msg);
	}
	else {
		$self->warning( "Found " . scalar(@aln_mlss_ids) . " alignments between " . $species1_gdb->name . " and " . $species2_gdb->name );
	}

	$self->param( 'aln_mlss_ids', \@aln_mlss_ids );
}

sub write_output {
	my $self = shift;

	my $dataflow = {
		'species1_id'  => $self->param( 'species1_id' ),
		'species2_id'  => $self->param( 'species2_id' ),
		'aln_mlss_ids' => $self->param( 'aln_mlss_ids' ),
	};

	print "FLOWING #1: ";
	print Dumper { mlss => $self->param('aln_mlss_ids') };
	print "FLOWING #2: ";
	print Dumper $dataflow;

	$self->dataflow_output_id( { mlss => $self->param('aln_mlss_ids') }, 1 ); # to write_threshold
	$self->dataflow_output_id( $dataflow, 2 ); # to prepare_orthologs
}

sub _overlap {
	my ( $self, $mlss_list_s1, $mlss_list_s2 ) = @_;

	my @common_mlss;
	foreach my $ms1 ( @{ $mlss_list_s1 } ) {
		foreach my $ms2 ( @{ $mlss_list_s2 } ) {
			push( @common_mlss, $ms1 ) if ( $ms1->dbID == $ms2->dbID );
		}
	}
	return \@common_mlss if ( scalar( @common_mlss ) > 0 );
	return;
}

1;