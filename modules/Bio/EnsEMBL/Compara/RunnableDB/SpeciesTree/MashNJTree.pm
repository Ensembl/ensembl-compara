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

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::MashNJTree

=head1 SYNOPSIS

Create a neighbour-joining tree from 'mash dist -t' output

=head1 DESCRIPTION

	Steps:
	1. convert input to phylip distance format. Input can be either
	   a path to a Mash tabular distance file or a 
	   Bio::EnsEMBL::Compara::Utils::DistanceMatrix object. This 
	   step also involves replacing species names with their 
	   genome_db_id - phylip has a 10-character limit on species 
	   names and this would not be unique in our set of species 
	   (naked mole rat, for example)
	2. run rapidnj, disallowing negative branch lengths
	3. replace genome_db_ids with species names
	4. 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::MashNJTree;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Utils::DistanceMatrix;
use File::Basename;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

	my $distance_file = $self->param('mash_output_file');
	my $distance_matrix = $self->param('distance_matrix');
	my $working_dir = $self->param('working_dir') || $self->worker_temp_directory;

	$distance_matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new( -file => $self->param_required('mash_output_file') ) if !$distance_matrix;
	my $phylip_file = "$working_dir/distances.phy";
	$distance_matrix->phylip_from_matrix($phylip_file);

	$self->param('phylip_file', $phylip_file);
	
}

sub run {
	my $self = shift;

	my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
	my $rapidnj_exe = $self->param_required('rapidnj_exe');
	my $phylip_file = $self->param_required('phylip_file');

	# run rapidnj
	my $rapidnj_cmd = "$rapidnj_exe $phylip_file --no-negative-length";
	print " --- CMD: $rapidnj_cmd\n";
	my $tree = $self->run_command($rapidnj_cmd)->out;

	die $tree unless $tree =~ /^\(/; # rapidnj writes errors to STDOUT :/

	$tree =~ s/[\\\']+//g;
	$self->param('newick_tree', $tree);
	
	if ( $self->param('output_file') ) {
		my $output_file = $self->param('output_file');
		print STDERR "Writing species tree to $output_file...\n" if $self->debug;
		$self->_spurt( $output_file, $tree );
	}
}

sub write_output {
	my $self = shift;

	# flow trees out to accu to be picked up and reconstructed by graft_subtrees
	my $dataflow = {
		group_key  => $self->param_required('group_key'),
		group_info => {
			tree => $self->param('newick_tree'),
		}
	};
	$dataflow->{group_info}->{outgroup} = 'gdb' . $self->param('outgroup') if $self->param('outgroup');
	$self->dataflow_output_id( $dataflow, 1 );
}

1;