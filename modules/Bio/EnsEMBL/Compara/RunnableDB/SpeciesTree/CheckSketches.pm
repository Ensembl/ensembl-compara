=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

sub fetch_input {
	my $self = shift;

	my $collection = $self->param('collection');
	my $species_set_id = $self->param('species_set_id');

	die "Need either collection or species_set_id defined!" unless ( $collection || $species_set_id );

	my $dba = $self->compara_dba;
	my $ss_adaptor = $dba->get_SpeciesSetAdaptor;
	my $species_set;
	if ( $collection ) {
		$species_set = $ss_adaptor->fetch_collection_by_name($collection);
	} elsif ( $species_set_id ) {
		$species_set = $ss_adaptor->fetch_by_dbID($species_set_id);
		$self->param('collection', $species_set->name); # set this for file naming later
	}
	



	$self->param( 'genome_dbs', $species_set->genome_dbs );
}

sub run {
	my $self = shift;
	
	my @gdb_ids_no_sketch;
	my @path_list;

	foreach my $gdb ( @{ $self->param_required('genome_dbs') } ) {
		my $mash_path = $self->mash_file_from_gdb($gdb);
		push( @gdb_ids_no_sketch, {genome_db_id => $gdb->dbID, genome_dump_file => "${mash_path}.fa"} ) unless -e $mash_path;
		push( @path_list, $mash_path );
	}
	$self->param('missing_sketch_gdb_ids', \@gdb_ids_no_sketch);
	$self->param('mash_file_list', \@path_list);
}

sub write_output {
	my $self = shift;

	foreach my $gdb_id ( @{ $self->param('missing_sketch_gdb_ids') } ) {
		$self->dataflow_output_id( { genome_db_id => $gdb_id }, 2 );
	}
	my $input_file = join(' ', @{ $self->param('mash_file_list') });
	$self->dataflow_output_id( { input_file => $input_file, out_prefix => $self->param('collection') }, 1 );
}

sub mash_file_from_gdb {
	my $self = shift;
	my $gdb  = shift;

	my $sketch_dir = $self->param_required('sketch_dir');
	my $prefix = $gdb->name . "." . $gdb->assembly;
	my @found_files = glob "$sketch_dir/$prefix.*";
	return $found_files[0] if $found_files[0];
	return "$sketch_dir/$prefix"; # to pass to dump_genome
}

1;