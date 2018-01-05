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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCFastTrees

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $ncfasttree = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCFastTrees->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$ncfasttree->fetch_input(); #reads from DB
$ncfasttree->run();
$ncfasttree->write_output(); #writes to DB

=head1 DESCRIPTION

This RunnableDB builds fast phylogenetic trees using examl and FastTree2. It is useful in cases where the alignments are too big to build the usual examl trees in PrepareSecStructModels and SecStructModelTree.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable
  +- Bio::EnsEMBL::Hive::Process

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCFastTrees;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use base ('Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCStoreTree');

=head2 fetch_input

    Title    : fetch_input
    Usage    : $self->fetch_input
    Function : Fetches input data from the database+
    Returns  : none
    Args     : none

=cut

sub fetch_input {
    my ($self) = @_;

    ## FastTree2 uses all the cores available by default. We want to limit this because we may have already asked for a limited amount of cores in our resource description
    ## To limit this the OMP_NUM_THREADS env variable must be set
    ## We assume that 'examl_number_of_cores' param is set to the number of cores specified in the resource description
    $ENV{'OMP_NUM_THREADS'} = $self->param('examl_number_of_cores');

    my $nc_tree_id = $self->param_required('gene_tree_id');

    my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id) or $self->throw("Couldn't fetch nc_tree with id $nc_tree_id\n");
    $self->param('gene_tree', $nc_tree);
    $self->_load_species_tree_string_from_db();

    my $aln = $self->compara_dba->get_GeneAlignAdaptor->fetch_by_dbID($self->param_required('alignment_id'));
    print STDERR scalar (@{$nc_tree->get_all_Members}), "\n";
    $nc_tree->alignment($aln);

    $self->param('input_aln',  $self->_dumpMultipleAlignmentToWorkdir($nc_tree, 1));
}

=head2 run

    Title     : run
    Usage     : $self->run
    Function  : runs something
    Returns   : none
    Args      : none

=cut

sub run {
    my ($self) = @_;

    $self->_run_fasttree;
    return if scalar(@{ $self->param('gene_tree')->get_all_leaves }) < 4;
    $self->_run_parsimonator;
    $self->_run_parse_examl;
    $self->_run_examl;
}


##########################################
#
# internal methods
#
##########################################

sub _run_fasttree {
    my $self = shift;
    my $aln_file;
    if (defined ($self->param('aln_fasta'))) {
        $aln_file = $self->param('aln_fasta');
    } else {
        $aln_file = $self->param('input_aln');
    }
#    my $aln_file = $self->param('input_aln');
    return unless (defined($aln_file));

    my $root_id = $self->param('gene_tree')->root_id;
    my $fasttree_tag = $root_id . ".". $self->worker->process_id . ".fasttree";

    my $fasttree_exe = $self->require_executable('fasttree_exe');

    my $fasttree_output = $self->worker_temp_directory . "/FastTree.$fasttree_tag";
    my $tag = defined $self->param('fastTreeTag') ? $self->param('fastTreeTag') : 'ft_it_nj';
#    my $tag = 'ft_it_nj';
    my $cmd = $fasttree_exe;
    $cmd .= " -nt -quiet -nopr";
    $cmd .= " $aln_file";
    $cmd .= " > $fasttree_output";

    $self->run_command($cmd, { die_on_failure => 1 } );

    $self->store_newick_into_nc_tree($tag, $fasttree_output);

    return 1;
}

sub _run_parsimonator {
    my ($self) = @_;
    my $aln_file = $self->param('input_aln');
    my $worker_temp_directory = $self->worker_temp_directory;
    die "$aln_file is not defined" unless (defined($aln_file));
#    return unless(defined($aln_file));

    my $root_id = $self->param('gene_tree')->root_id;
    my $parsimonator_tag = $root_id . "." . $self->worker->process_id . ".parsimonator";

    my $parsimonator_exe = $self->require_executable('parsimonator_exe');

    my $cmd = $parsimonator_exe;
    $cmd .= " -s $aln_file";
    $cmd .= " -n $parsimonator_tag";
    $cmd .= " -p 12345";

    $self->run_command("cd $worker_temp_directory; $cmd", { die_on_failure => 1 } );

    my $parsimonator_output = $worker_temp_directory . "/RAxML_parsimonyTree.${parsimonator_tag}.0";
    $self->param('parsimony_tree_file', $parsimonator_output);

    return;
}

sub _run_parse_examl {
    my ($self) = @_;
    my $aln_file = $self->param('input_aln');
    my $worker_temp_directory = $self->worker_temp_directory;
    my $parse_examl_exe = $self->require_executable('parse_examl_exe');

    my @splited_path = split "/", $aln_file; #we need to use split to get the actual file excluding the path as parse-examl does not like path in the name of the file 
    my $aln_filename = $splited_path[-1];
    my $cmd = $parse_examl_exe;
    $cmd .= " -s $aln_filename";
    $cmd .= " -m DNA";
    $cmd .= " -n $aln_filename";

    $self->run_command("cd $worker_temp_directory; $cmd", { die_on_failure => 1 });

    my $binary_input_aln = $aln_file . ".binary";
    $self->param('binary_input_aln', $binary_input_aln);

    return;
}

sub _run_examl {
    my ($self) = @_;
    my $aln_file = $self->param('input_aln');
    my $binary_input_aln = $self->param('binary_input_aln');
    my $parsimony_tree = $self->param('parsimony_tree_file');
    my $worker_temp_directory = $self->worker_temp_directory;
    my $root_id = $self->param('gene_tree')->root_id;

    my $examl_tag = $root_id . "." . $self->worker->process_id . ".examl";
    $self->examl_exe_decision();
    my $examl_exe = $self->require_executable('examl_exe');
    my $examl_number_of_cores = $self->param('examl_number_of_cores');

    my $tag = defined $self->param('examl') ? $self->param('examl') : 'ft_it_ml';
#    my $tag = 'ft_it_ml';
    my $cmd = $self->require_executable('mpirun_exe').' -np ' . $examl_number_of_cores . " " . $examl_exe;
    $cmd .= " -m GAMMA";
    $cmd .= " -s $binary_input_aln";
    $cmd .= " -t $parsimony_tree";
    $cmd .= " -n $examl_tag";

    $self->run_command("cd $worker_temp_directory; $cmd", { die_on_failure => 1 });

    my $examl_output = $worker_temp_directory . "/ExaML_result.${examl_tag}";
    $self->store_newick_into_nc_tree($tag, $examl_output);

    # Unlink run files
    my $temp_regexp = $self->worker_temp_directory;
    unlink <*$examl_tag*>;

    return
}



1;

