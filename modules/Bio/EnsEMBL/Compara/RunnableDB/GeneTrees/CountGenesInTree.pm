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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CountGenesInTree

=head1 DESCRIPTION

Wraps count_genes_in_tree.pl script, parses its output
and stores its results in the database.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CountGenesInTree;

use strict;
use warnings;

use JSON qw(decode_json);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('mlss_id');
    my $genome_db_id = $self->param_required('genome_db_id');

    my $tree_adaptor = $self->compara_dba->get_SpeciesTreeAdaptor();
    my $species_tree = $tree_adaptor->fetch_by_method_link_species_set_id_label($mlss_id, 'default');
    my $species_tree_node = $species_tree->root->find_leaves_by_field('genome_db_id', $genome_db_id)->[0];
    $self->param('species_tree_node', $species_tree_node);
}

sub run {
    my $self = shift @_;

    my $db_url = $self->compara_dba->url;
    my $mlss_id = $self->param_required('mlss_id');
    my $genome_db_id = $self->param_required('genome_db_id');
    my $gene_count_exe = $self->param_required('gene_count_exe');

    my $cmd = [ $gene_count_exe, '-url', $db_url, '-mlss_id', $mlss_id, '-genome_db_id', $genome_db_id ];
    my $output = $self->get_command_output($cmd);
    my $gene_tree_stats = decode_json($output);

    $self->param('nb_genes_in_tree', $gene_tree_stats->{'nb_genes_in_tree'});
    $self->param('nb_genes_unassigned', $gene_tree_stats->{'nb_genes_unassigned'});
}

sub write_output {
    my $self = shift @_;
    my $species_tree_node = $self->param('species_tree_node');
    $species_tree_node->store_tag('nb_genes_in_tree', $self->param('nb_genes_in_tree'));
    $species_tree_node->store_tag('nb_genes_unassigned', $self->param('nb_genes_unassigned'));
}


1;
