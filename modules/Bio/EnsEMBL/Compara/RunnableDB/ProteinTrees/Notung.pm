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

use base ('Bio::EnsEMBL::Compara::RunnableDB::RunCommand', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');


sub param_defaults {
    return {
        'check_split_genes' => 1,
        'do_transactions'   => 1,
        'cmd_notung'        => 'java -Xmx1550M -jar #notung_jar# #gene_tree_file# -s #species_tree_file# --rearrange --treeoutput newick --speciestag postfix --edgeweights length --threshold 0.9 --silent --nolosses',
        'cmd_treebest'      => '#treebest_exe# sdi -s #species_tree_file# #gene_tree_file#.rearrange.0 > #gene_tree_file#.sdi',
    };
}


sub fetch_input {
    my $self = shift @_;

    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);

    my $gene_tree_id     = $self->param_required('gene_tree_id');
    my $gene_tree        = $self->param('tree_adaptor')->fetch_by_dbID( $gene_tree_id ) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";

    $self->param('gene_tree', $gene_tree);

    $gene_tree->preload();
    $gene_tree->print_tree(10) if($self->debug);

}


sub run {
    my $self = shift;
    $self->cleanup_worker_temp_directory;
    $self->run_generic_command;
}


sub write_output {
    my $self = shift;

    $self->store_genetree($self->param('gene_tree'), []);
    $self->param('gene_tree')->store_tag('notung_runtime', $self->param('runtime_msec'));
}


sub post_cleanup {
  my $self = shift;

  if(my $gene_tree = $self->param('gene_tree')) {
    $gene_tree->release_tree;
    $self->param('gene_tree', undef);
  }

  $self->SUPER::post_cleanup if $self->can("SUPER::post_cleanup");
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
    $self->param('gene_tree_file', $self->get_gene_tree_file($self->param('gene_tree')));

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

    $self->param('runtime_msec', time()*1000-$starttime);
}


sub get_gene_tree_file {
    my ($self, $gene_tree) = @_;

    # horrible hack: we replace taxon_id with species_tree_node_id
    foreach my $leaf (@{$gene_tree->root->get_all_leaves}) {
        $leaf->taxon_id($leaf->genome_db->species_tree_node_id);
    }
    my $gene_tree_file = sprintf('%s/gene_tree_%d.nhx', $self->worker_temp_directory, $gene_tree->root_id);
    open( my $speciestree, '>', $gene_tree_file) or die "Could not open '$gene_tree_file' for writing : $!";
    print $speciestree $gene_tree->newick_format('ryo','%{-m}%{"_"-x}:%{d}');;
    close $speciestree;

    return $gene_tree_file;
}

sub _load_species_tree_string_from_db {
    my ($self) = @_;
    my $species_tree = $self->param('gene_tree')->species_tree;
    $species_tree->attach_to_genome_dbs();
    $self->param('species_tree_string', $species_tree->root->newick_format('ryo', '%{o}'));
}



1;
