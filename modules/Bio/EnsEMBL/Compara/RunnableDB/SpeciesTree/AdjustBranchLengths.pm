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

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::AdjustBranchLengths

=head1 SYNOPSIS

Given a topology tree and a mash distance matrix, recompute branch lengths 
using erable (https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4705742/)

=head1 DESCRIPTION

	

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::AdjustBranchLengths;

use strict;
use warnings;
use File::Basename;
use Bio::EnsEMBL::Compara::Utils::DistanceMatrix;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'output_display_name'  => 0, # when genome_db_ids are replaced in the final tree, 
        							 # use $gdb->display_name instead. default is $gdb->name
    };
}

sub fetch_input {}

sub run {
	my $self = shift;

	# generate file in correct format for erable
	my $working_dir = $self->param('working_dir') || $self->worker_temp_directory;
	my $erable_phylip = "$working_dir/erable.phy";
	my $mash_matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new( -file => $self->param_required('mash_dist_file') );
	$mash_matrix = $mash_matrix->convert_to_genome_db_ids($self->compara_dba->get_GenomeDBAdaptor);
	$mash_matrix->phylip_from_matrix($erable_phylip, 'multi');

	# write topology tree to file
	my $tree_file = "$working_dir/topology.nwk";
	$self->_spurt($tree_file, $self->param_required('tree'));
	print "topology tree written to $tree_file\n";

	# run erable
	my $erable_exe = $self->param_required('erable_exe');
	my $erable_cmd = "$erable_exe -i $erable_phylip -t $tree_file";
	my $erable_run = $self->run_command($erable_cmd);

	# correct negative branch lengths
	my $tree = $self->_slurp("$erable_phylip.lengths.nwk");
	$tree = $self->_correct_negative_brlens( $tree );

	# replace genome_db_ids with species names
	my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
	while ( $tree =~ m/gdb([0-9]+)/ ) {
		my $this_gdb_id = $1;
		my $gdb = $genome_db_adaptor->fetch_by_dbID($this_gdb_id);
		my $species_name = $self->param('output_display_name') ? $gdb->display_name : $gdb->name;
		$tree =~ s/gdb$this_gdb_id/$species_name/;
	}


	$self->param('erable_tree', $tree);
}

sub write_output {
	my $self = shift;

	my $erable_tree = $self->param_required('erable_tree');
	my $outfile = $self->param('output_file');

	if ( $outfile ) {
		$self->_spurt($outfile, $erable_tree);
		# $self->input_job->autoflow(0);
		# $self->complete_early("Final tree written to $outfile");
	} else {
		$self->dataflow_output_id( { tree => $erable_tree }, 2 ); # for testing mostly
	}
}

sub _correct_negative_brlens {
	my ( $self, $tree ) = @_;

	# replace negative lengths first
	# very short brlens can be represented like '1e-06', so add e, - to regex
	while ( $tree =~ /:(-[0-9\.e\-]+)/ ) {
		$tree =~ s/$1/1e-04/;
	}

	# replace 0 length branches with short positive length
	while ( $tree =~ /(:0.0\D)/ ) {
		$tree =~ s/$1/:1e-03/g;
	}

	return $tree;
}

1;
