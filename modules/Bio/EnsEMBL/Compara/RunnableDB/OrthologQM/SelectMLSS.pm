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

	# if ( $self->param('alt_aln_db') ) { $dba = $self->get_cached_compara_dba('alt_aln_db'); }
	# else { $dba = $self->compara_dba }
	$dba = $self->get_cached_compara_dba('master_db');

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

	# check if an EPO exists between both species
	my $mlss_list_s1 = $mlss_adap->fetch_all_by_method_link_type_GenomeDB( "EPO", $species1_gdb );
	my $mlss_list_s2 = $mlss_adap->fetch_all_by_method_link_type_GenomeDB( "EPO", $species2_gdb );

	my $common_mlss_list = $self->_overlap( $mlss_list_s1, $mlss_list_s2 );

	# }
	
	if ( defined $common_mlss_list ){
		foreach my $common_mlss ( @{ $common_mlss_list } ) {
			next unless $common_mlss->is_current;
			push( @aln_mlss_ids, $common_mlss->dbID );
			$self->warning( "Found EPO alignment. mlss_id = " . $common_mlss->dbID );
		}
	}
	# Last, look for a LASTZ aln between pair
	my $lastz = $mlss_adap->fetch_by_method_link_type_genome_db_ids( "LASTZ_NET", [ $species1_gdb->dbID, $species2_gdb->dbID ] );
	if ( defined $lastz && $lastz->is_current ) {
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

	# Find alignment db for these mlsses
	# $self->_map_mlss_to_db( \@aln_mlss_ids );

	$self->param( 'aln_mlss_ids', \@aln_mlss_ids );
}

sub write_output {
	my $self = shift;

	my ( $species1_id, $species2_id ) = ( $self->param( 'species1_id' ), $self->param( 'species2_id' ) );

	my $accu_dataflow = {
		'species1_id'  => $species1_id,
		'species2_id'  => $species2_id,
		'aln_mlss_ids' => $self->param( 'aln_mlss_ids' ),
	};
	$self->param('accu_dataflow', $accu_dataflow);

	my $br1_dataflow = { species => "$species1_id - $species2_id", accu_dataflow => $accu_dataflow };
	$self->dataflow_output_id( $br1_dataflow, 1 ); # to accu
	
	my $mlss_db_map = $self->_map_mlss_to_db( $self->param('aln_mlss_ids') );
	my @mlss_ids_sorted = sort keys(%$mlss_db_map); # important for testing
	foreach my $mlss_id ( @mlss_ids_sorted ) {
		my $this_dataflow = { mlss_id => $mlss_id, mlss_db => $mlss_db_map->{$mlss_id} };
		$self->dataflow_output_id( $this_dataflow, 2 ); # to accu
	}
	

	# print "FLOWING #1: ", Dumper { mlss => $self->param('aln_mlss_ids') };
	# print "FLOWING #2: ", Dumper $dataflow;

	# $self->dataflow_output_id( { mlss => $self->param('aln_mlss_ids') }, 1 ); # to write_threshold
	# $self->dataflow_output_id( $dataflow, 2 ); # to prepare_orthologs
	# $self->dataflow_output_id( {}, 3 );

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

sub _map_mlss_to_db {
	my ( $self, $mlsses ) = @_;

	my $aln_dbs = $self->param('alt_aln_dbs');
	# my %mlss_db_mapping = %{ $self->param('mlss_db_mapping') };
	my %mlss_db_mapping;

	if ( $aln_dbs and scalar @$aln_dbs > 0 ) {
		foreach my $db_url ( @$aln_dbs ) {
			my $this_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $db_url );
			my $mlss_adap = $this_dba->get_MethodLinkSpeciesSetAdaptor;

			foreach my $mlss_id ( @$mlsses ) {
				print "looking in $db_url for $mlss_id...\n" if $self->debug;
				my $this_mlss = $mlss_adap->fetch_by_dbID($mlss_id);
				if ( $this_mlss ) {
					print " --- FOUND!\n" if $self->debug;
					$mlss_db_mapping{$this_mlss->dbID} = $db_url;
				} else {
					print " --- NOT FOUND!\n" if $self->debug;
				}
				
			}
		}
	} else {
		foreach my $this_mlss_id ( @$mlsses ) {
			$mlss_db_mapping{$this_mlss_id} = $self->param('compara_db');
		}
	}

	# $self->param('mlss_db_mapping', \%mlss_db_mapping);

	# check all have been mapped
	foreach my $this_mlss_id ( @$mlsses ) {
		die "MLSS $this_mlss_id can't be found in the given alignment databases\n" unless ( $mlss_db_mapping{$this_mlss_id} );
	}
	return \%mlss_db_mapping;
}

1;
