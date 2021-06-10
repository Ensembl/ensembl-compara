=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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


sub run {
	my $self = shift;

	# generate file in correct format for erable
	my $working_dir = $self->param('working_dir') || $self->worker_temp_directory;
	my $erable_phylip = "$working_dir/erable.phy";

	my $ss_adaptor = $self->compara_dba->get_SpeciesSetAdaptor;
	my $species_set = $ss_adaptor->fetch_by_dbID($self->param_required('species_set_id'));
	my @genome_dbs = grep {
		$_->name ne 'ancestral_sequences'
		&& !($_->is_polyploid && !defined $_->genome_component)
	} @{ $species_set->genome_dbs };

	my $gdb_id_map = { map {$_->_get_genome_dump_path($self->param('genome_dumps_dir')) => $_->dbID} @genome_dbs };

	my $mash_matrix = Bio::EnsEMBL::Compara::Utils::DistanceMatrix->new( -file => $self->param_required('mash_dist_file') );
	$mash_matrix = $mash_matrix->filter_and_convert_genome_db_ids($gdb_id_map);
	$mash_matrix->phylip_from_matrix($erable_phylip, 'multi');

	# write topology tree to file
	my $tree_file = "$working_dir/topology.nwk";
	my $unrooted_tree = $self->_write_unrooted_tree($tree_file); # erable requires unrooted input
	print "unrooted topology tree written to $tree_file\n" if $self->debug;

	# run erable
	my $erable_exe = $self->param_required('erable_exe');
	my $erable_cmd = "$erable_exe -i $erable_phylip -t $tree_file";
	my $erable_run = $self->run_command($erable_cmd);

	# correct negative branch lengths
	my $tree = $self->_slurp("$erable_phylip.lengths.nwk");
	print "\n -- TREE AFTER ERABLE RUN: $tree\n" if $self->debug;
	$tree = $self->_correct_negative_brlens( $tree );
	print "\n -- TREE AFTER NEGATIVE LEN CORRECTION: $tree\n" if $self->debug;

	# reroot the tree if outgroup is given
	my $outgroup_id = $self->param('outgroup_id');
	if ( $outgroup_id ) { 
		my $unrooted_erable_treefile = "$working_dir/unroot.erable.nwk";
		$self->_spurt($unrooted_erable_treefile, $tree);
		my $reroot_cmd = [$self->param_required('reroot_script'), '--tree', $unrooted_erable_treefile, '--outgroup', "gdb$outgroup_id"];
		$tree = $self->get_command_output($reroot_cmd);
		chomp $tree;
	}

	# replace genome_db_ids with species names
	my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
	while ( $tree =~ m/gdb([0-9]+)/ ) {
		my $this_gdb_id = $1;
		my $gdb = $genome_db_adaptor->fetch_by_dbID($this_gdb_id);
		my $gcomp = $gdb->genome_component ? ".comp" . $gdb->genome_component : '';
		my $species_name = $self->param('output_display_name') ? $gdb->display_name : $gdb->name . $gcomp;
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

sub _write_unrooted_tree {
	my ($self, $outfile) = @_;

	my $tmp_dir = $self->worker_temp_directory;
	my $rooted_tree = $self->param_required('tree');
	my $rooted_tree_file = "$tmp_dir/rooted.topology.nwk";
	$self->_spurt($rooted_tree_file, $rooted_tree);

	my $unroot_script = $self->param_required('unroot_script');
	my $unroot_run = $self->run_command("$unroot_script -t $rooted_tree_file > $outfile");
	die $unroot_run->err if $unroot_run->err;
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
