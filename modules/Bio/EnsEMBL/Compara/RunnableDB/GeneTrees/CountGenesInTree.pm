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
  developers list at <https://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <https://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CountNumGenesInTrees

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CountGenesInTree;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('mlss_id');
    my $genome_db_id = $self->param_required('genome_db_id');

    my $tree_adaptor = $self->compara_dba->get_SpeciesTreeAdaptor;
    my $species_tree = $tree_adaptor->fetch_by_method_link_species_set_id_label($mlss_id, 'default');
    my $species_tree_node = $species_tree->root->find_leaves_by_field('genome_db_id', $genome_db_id)->[0];
    $self->param('species_tree_node', $species_tree_node);

    my $gene_member_adaptor = $self->compara_dba->get_GeneMemberAdaptor;
    my $total_num_genes = scalar @{ $gene_member_adaptor->fetch_all_by_GenomeDB($genome_db_id) };
    $self->param('total_num_genes', $total_num_genes);

    my $total_num_unassigned = $self->count_gdb_unassigned_genes($genome_db_id);
    $self->param('total_num_unassigned', $total_num_unassigned);
}


sub run {
    my ($self) = @_;
    $self->param('nb_genes_in_tree', $self->param('total_num_genes') - $self->param('total_num_unassigned'));
}


sub write_output {
    my $self = shift @_;
    my $species_tree_node = $self->param('species_tree_node');
    $species_tree_node->store_tag('nb_genes_in_tree', $self->param('nb_genes_in_tree'));
    $species_tree_node->store_tag('nb_genes_unassigned', $self->param('total_num_unassigned'));
}


sub count_gdb_unassigned_genes {
    my ($self, $genome_db_id) = @_;

    my $sql = q/
        SELECT COUNT(*) FROM gene_member mg
        LEFT JOIN gene_tree_node gtn ON (mg.canonical_member_id = gtn.seq_member_id)
        WHERE gtn.seq_member_id IS NULL AND mg.genome_db_id = ?
    /;

    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute($genome_db_id);
    my $total_num_unassigned = $sth->fetchrow();
    $sth->finish();

    return $total_num_unassigned;
}


1;
