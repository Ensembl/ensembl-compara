=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Notung;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::Utils::Cigars;

use Time::HiRes qw(time gettimeofday tv_interval);
use Data::Dumper;
use File::Glob;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable');


sub param_defaults {
    my $self = shift;
    return {
        'check_split_genes' => 1,
        'read_tags'         => 0,
        'do_transactions'   => 1,
        'cmd_notung'        => 'java -Xmx1550M -jar #notung_jar# #gene_tree_file# -s #species_tree_file# --rearrange --treeoutput newick --speciestag postfix --edgeweights length --threshold 0.9 --silent --nolosses',
        'cmd_treebest'      => '#treebest_exe# sdi -s #species_tree_file# #gene_tree_file#.rearrange.0 > #gene_tree_file#.sdi',
        'ryo_species_tree'  => '%{o}',
        'command_tag_runtime'   => 'notung_runtime',
        'label'             => 'binary',
    };
}




sub run {
    my $self = shift;
    $self->cleanup_worker_temp_directory;
    $self->run_generic_command;
}




##########################################
#
# internal methods
#
##########################################


sub run_generic_command {
    my $self = shift;

    my $gene_tree = $self->param('gene_tree');
    my $newick;

    my $starttime = time()*1000;

    # The order is important to have the stn_ids tags attached to the gene-tree leaves
    $self->param('species_tree_file', $self->get_species_tree_file());

    my $other_trees = $self->param('tree_adaptor')->fetch_all_linked_trees($self->param('gene_tree'));
    my ($treebest_tree) = grep {$_->clusterset_id eq 'treebest'} @$other_trees;
    $self->param('gene_tree_file', $self->get_gene_tree_file($treebest_tree));

    foreach my $cmd_param (qw(cmd_notung cmd_treebest)) {
        my $cmd = sprintf('cd %s; %s', $self->worker_temp_directory, $self->param_required($cmd_param));
        my $run_cmd = $self->run_command($cmd);
        if ($run_cmd->exit_code) {
            $self->throw(sprintf("'%s' resulted in an error code=%d. stderr is:%s\n", $run_cmd->cmd, $run_cmd->exit_code, $run_cmd->err));
        }
    }

    my $output = $self->_slurp(sprintf('%s.sdi', $self->param('gene_tree_file')));

    #parse the tree into the data structure:
    $self->parse_newick_into_tree( $output, $self->param('gene_tree') );

    foreach my $node (@{$self->param('gene_tree')->get_all_nodes}) {
        next if $node->is_leaf;
        die if scalar(@{$node->children}) != 2;
    }

    $self->param('command_run', 1);
    $self->param('runtime_msec', time()*1000-$starttime);
}






1;
