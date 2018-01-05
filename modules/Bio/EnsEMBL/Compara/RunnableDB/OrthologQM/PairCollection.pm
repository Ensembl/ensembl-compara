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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection

=head1 SYNOPSIS

	For a given species set, pair up members and fan out

=head1 DESCRIPTION

	Inputs:
	compara_db 		URL to database containing data
	ref_species		pairs not containing this reference species will be omitted (optional)
	either:
		species1 & species2 : names of species of interest
		species_set_name    : name of species_set
		species_set_id      : dbID of species set of interest (usually used where species_set_name is ambiguous)
	
	Output:
		pairs of genome_db_ids e.g. {species1_id => 150, species2_id => 125} 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

	# import params to variables
	my $species_set_name = $self->param( 'species_set_name' );
	my $species_set_id   = $self->param( 'species_set_id' );
	my $ref_species      = $self->param( 'ref_species' );
	my $compara_db = $self->param( 'compara_db' );
	my $species1 = $self->param( 'species1' );
	my $species2 = $self->param( 'species2' );

	$self->warning("No compara_db provided - defaulting to hive DB") unless ( defined $compara_db );

	# fetch required adaptors
	my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
	my $ss_adaptor = $self->compara_dba->get_SpeciesSetAdaptor;

	# find genome_db_id for ref species
	if ( defined $ref_species ){
		my $ref_gdb = $gdb_adaptor->fetch_by_name_assembly( $ref_species );
		if ( !defined $ref_gdb ){
			$self->warning("Can't find $ref_species in the database. Continuing without reference..");
		}
		else {
			$self->param( 'ref_gdb_id', $ref_gdb->dbID );
		}
	}

	# find genome_dbs for species1 and species2 if not running on a species set
	if ( !defined $species_set_name && !defined $species_set_id ){
		die "Please provide a species set name OR individual species" unless ( $species1 && $species2 );
		
		# find GenomeDBs for each species
		my $species1_gdb = $gdb_adaptor->fetch_by_name_assembly($species1);
		my $species2_gdb = $gdb_adaptor->fetch_by_name_assembly($species2);

		die "Cannot find $species1 in the database\n" unless ( defined $species1_gdb );
		die "Cannot find $species2 in the database\n" unless ( defined $species2_gdb );

		$self->param( 'genome_db_ids', [ $species1_gdb->dbID, $species2_gdb->dbID ] );

		return 1;
	}

	# if running on a species set, add all members gdb_ids to the species list
	my $ss; 
	if ( $species_set_name ){
		my @ss_list = @{ $ss_adaptor->fetch_all_by_name( $species_set_name ) };
		if ( scalar( @ss_list ) > 1 ){
			my @id_list = map { $_->dbID } @ss_list;
			die "More than one species set exists for '$species_set_name':\n" . join("\n", @id_list) . "\nPlease specify the ID of the set of interest (species_set_id)\n";
		}
		$ss = $ss_list[0];
		die "Cannot find species_set named '$species_set_name' in db ($compara_db)" unless ( defined $ss );
		$self->param( 'species_set_id', $ss->dbID );
	}
	elsif ( $species_set_id ){
		$ss = $ss_adaptor->fetch_by_dbID($species_set_id);
		die "Cannot find species_set with id '$species_set_id' in db ($compara_db)" unless ( defined $ss );
	}

	my $gdb_list = $ss->genome_dbs;
	my @species_list;
	foreach my $gdb ( @{ $gdb_list } ) {
		push( @species_list, $gdb->dbID );
	}
	$self->param( 'genome_db_ids', \@species_list );
}

sub run {
	my $self = shift;

	my @species_list = @{ $self->param( 'genome_db_ids' ) };
	my $ref_gdb_id   = $self->param('ref_gdb_id');
	my $ss_id        = $self->param('species_set_id');

	my @pairs;
	if ( $ref_gdb_id ) { # ref vs all
		foreach my $s ( @species_list ){
			next if $s == $ref_gdb_id;
			my $this_pair = {'species1_id' => $ref_gdb_id, 'species2_id' => $s};
			$this_pair->{species_set_id} = $ss_id if ( $ss_id );
			push( @pairs, $this_pair );
		}
	}
	else { # all vs all
		my @ref_list = @species_list;
		while( my $r = shift @ref_list ){
			my @nonref_list = @ref_list;
			foreach my $nr ( @nonref_list ){
				my $this_pair = {'species1_id' =>$r, 'species2_id' => $nr};
				$this_pair->{species_set_id} = $ss_id if ( $ss_id );
				push( @pairs, $this_pair );
			}
		}
	}
	$self->param('genome_db_pairs', \@pairs);
}

sub write_output {
	my $self = shift;

	$self->dataflow_output_id( $self->param('genome_db_pairs'), 2 ); # array of input_ids to select_mlss
	
	# Removes all scores in the ortholog_quality table associated with the list of input MLSS
	my $mlss_ids = $self->param('aln_mlss_ids');

	if ( defined $mlss_ids && scalar( @{$mlss_ids} ) ) {
            $self->dataflow_output_id( { aln_mlss_id => $_ }, 3 ) for @{$mlss_ids}; # to reset_mlss
        }
}

1;
