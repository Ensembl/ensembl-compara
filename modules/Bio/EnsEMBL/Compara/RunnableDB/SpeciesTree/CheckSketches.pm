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

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::CheckSketches

=head1 SYNOPSIS

Check if mash sketches (https://genomebiology.biomedcentral.com/articles/10.1186/s13059-016-0997-x) exist
for all species in a given collection

=head1 DESCRIPTION

Check mash sketch files exist for each member of a collection 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::CheckSketches;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Compara::Utils::DistanceMatrix;
use Data::Dumper;

sub fetch_input {
	my $self = shift;

	my $collection = $self->param('collection');
	my $species_set_id = $self->param('species_set_id');
	my $genome_db_ids = $self->param('genome_db_ids');

	die "Need either collection, species_set_id or genome_db_ids defined!" unless ( $collection || $species_set_id || $genome_db_ids );

	my $dba = $self->compara_dba;
	my $gdb_adaptor = $dba->get_GenomeDBAdaptor;
	my $ss_adaptor = $dba->get_SpeciesSetAdaptor;

	my @genome_dbs;
	if ( $genome_db_ids ) {
		foreach my $gdb_id ( @$genome_db_ids ) {
			my $this_gdb = $gdb_adaptor->fetch_by_dbID( $gdb_id );
			push( @genome_dbs, $this_gdb );
		}
	} else {
		my $species_set;
		if ( $collection ) {
			$species_set = $ss_adaptor->fetch_collection_by_name($collection);
		} elsif ( $species_set_id ) {
			$species_set = $ss_adaptor->fetch_by_dbID($species_set_id);
			$self->param('collection', $species_set->name); # set this for file naming later
		}
		@genome_dbs = @{ $species_set->genome_dbs };
	}
	
	# # add any optional outgroups
	# if ( $self->param('outgroup_gdbs') ) {
	# 	foreach my $gdb_id ( @{ $self->param('outgroup_gdbs') } ) {
	# 		my $this_gdb = $gdb_adaptor->fetch_by_dbID( $gdb_id );
	# 		die "Outgroup species genome_db $gdb_id could not be found in the database" unless $this_gdb;
	# 		push( @genome_dbs, $this_gdb );
	# 	}
	# }

	# print "\n\nGENOME_DBS:\n";
	# print Dumper \@genome_dbs;

	$self->param( 'genome_dbs', \@genome_dbs );
}

sub run {
	my $self = shift;
	
	my @gdb_ids_no_dump;
	my @gdb_ids_no_sketch;
	my @path_list;

	# perhaps there's already some distances computed?
	my $dist_file = $self->_check_for_distance_files();
	if ( defined $dist_file ) {
		$self->param('mash_dist_file', $dist_file);
		return;
	}

	foreach my $gdb ( @{ $self->param_required('genome_dbs') } ) {
		my $mash_path = $self->find_file_for_gdb($self->param_required('sketch_dir'), $gdb, ['msh']);
		my $dump_path = $self->find_file_for_gdb($self->param('multifasta_dir'), $gdb, ['fa', 'fa\.gz']);

		if ( -e $mash_path ) {
			push( @path_list, $mash_path );
		} 
		elsif ( -e $dump_path ) {
			push( @gdb_ids_no_sketch, { genome_db_id => $gdb->dbID, genome_dump_file => => $dump_path } );
		}
		else {
			push( @gdb_ids_no_dump, { genome_db_id => $gdb->dbID, genome_dump_file => "$mash_path.fa"} );
			push( @path_list, "$mash_path.fa.msh" );
		}
		
	}
	$self->param('gdb_ids_no_sketch', \@gdb_ids_no_sketch);
	$self->param('gdb_ids_no_dump', \@gdb_ids_no_dump);
	$self->param('mash_file_list', \@path_list);
}

sub write_output {
	my $self = shift;

	my $mash_dist_file = $self->param('mash_dist_file');
	if ( $mash_dist_file  ) {
		$self->dataflow_output_id( {mash_dist_file => $mash_dist_file}, 4 );
		$self->input_job->autoflow(0);
		$self->complete_early("Found distance file containing all genome_dbs: $mash_dist_file. Skipping Mash steps.");
	}

	$self->dataflow_output_id( $self->param('gdb_ids_no_dump'), 2 );
	$self->dataflow_output_id( $self->param('gdb_ids_no_sketch'), 3 );
	my $input_file = join(' ', @{ $self->param('mash_file_list') });
	$self->dataflow_output_id( { input_file => $input_file, out_prefix => $self->param('collection') }, 1 );
}

sub find_file_for_gdb {
	my ($self, $dir, $gdb, $suffixes) = @_;
	
	$suffixes = [''] unless defined $suffixes->[0];

	my $prefix = $gdb->name . "." . $gdb->assembly;
	foreach my $suffix ( @$suffixes ) {
		my @found_files = glob "$dir/$prefix.*$suffix";
		return $found_files[0] if $found_files[0];
	}
	return $self->param('output_dir') . "/$prefix"; # to pass to dump_genome
}

sub _check_for_distance_files {
	my $self = shift;

	my $dir = $self->param_required('sketch_dir');
	my @dist_files = glob "$dir/*.dists";
	my @needed_gdb_ids = map {$_->dbID} @{ $self->param('genome_dbs') };

	my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;

	foreach my $dfile ( @dist_files ) {
		print " --- checking $dfile\n";
		my $dist_matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new( -file => $dfile );
		$dist_matrix = $dist_matrix->convert_to_genome_db_ids($gdb_adaptor);

		my @matrix_members = $dist_matrix->members;
		my $overlap = $self->_overlap(\@needed_gdb_ids, \@matrix_members);
		print " --- --- overlap = $overlap (" . scalar @needed_gdb_ids . " needed)\n";
		return $dfile if $overlap >= scalar @needed_gdb_ids;
	}	

	return undef;
}

sub _overlap {
	my ( $self, $setA, $setB ) = @_;

	my $count = 0;
	foreach my $a ( @$setA ) {
		foreach my $b ( @$setB ) {
			$count++ if $a == $b;
		}
	}
	return $count;
}

1;