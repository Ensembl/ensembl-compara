=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::DBSQL::CAFEGeneFamilyAdaptor

=head1 DESCRIPTION

  CAFEGeneFamilyAdaptor - Information about CAFE gene families


=head1 APPENDIX

  The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::CAFEGeneFamilyAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::CAFEGeneFamily;

use base ('Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeAdaptor');


sub fetch_all {
    my ($self) = @_;

    return $self->generic_fetch();
}

sub fetch_by_GeneTree {
    my ($self, $geneTree) = @_;

    return undef unless (defined $geneTree);
    assert_ref($geneTree, 'Bio::EnsEMBL::Compara::GeneTree');

    my $node_id = $geneTree->root_id();
    return $self->fetch_by_gene_tree_root_id($node_id);
}

sub fetch_by_gene_tree_root_id {
    my ($self, $gene_tree_root_id) = @_;

    unless (defined $gene_tree_root_id) {
        throw("gene_tree_root_id must be defined");
    }
    my $constraint = "cgf.gene_tree_root_id=$gene_tree_root_id";

    return $self->generic_fetch($constraint)->[0];

}

sub fetch_all_by_method_link_species_set_id {
    my ($self, $mlss_id) = @_;

    my $species_tree_adaptor = $self->db->get_SpeciesTreeAdaptor;
    my $species_tree = $species_tree_adaptor->fetch_by_method_link_species_set_id_label($mlss_id, 'cafe');
    my $root_id = $species_tree->root->node_id();

    my $constraint = "str.root_id=$root_id";
    return $self->generic_fetch($constraint);
}

sub store {
    my ($self, $tree) = @_;

    my $sth = $self->prepare("INSERT INTO CAFE_gene_family (root_id, lca_id, gene_tree_root_id, pvalue_avg, lambdas) VALUES (?,?,?,?,?)");
    $sth->execute($tree->root->node_id, $tree->lca_id, $tree->gene_tree_root_id, $tree->pvalue_avg, $tree->lambdas);
    my $cafe_gene_family_id = $self->dbc->db_handle->last_insert_id(undef, undef, 'CAFE_gene_family', 'cafe_gene_family_id');
    $sth->finish;

    my $cafe_gene_family_node_adaptor = $self->db->get_CAFEGeneFamilyNodeAdaptor();
    $cafe_gene_family_node_adaptor->store($tree->root, $cafe_gene_family_id);

    return $cafe_gene_family_id;
}


#################################################
#
# subclass override methods
#
#################################################

sub _columns {
    return qw (cgf.cafe_gene_family_id
               cgf.root_id
               cgf.lca_id
               cgf.pvalue_avg
               cgf.lambdas
               cgf.gene_tree_root_id

               str.method_link_species_set_id
               str.species_tree
             );
}

sub _tables {
    return (['CAFE_gene_family', 'cgf'], ['species_tree_root', 'str']);
}

sub _left_join {
    return (['species_tree_root', 'str.root_id=cgf.root_id']);
}


sub _objs_from_sth {
    my ($self, $sth) = @_;

    my $tree_list = [];

    while (my $rowhash = $sth->fetchrow_hashref) {
        my $tree = $self->create_instance_from_rowhash($rowhash);
        push @$tree_list, $tree;
    }
    return $tree_list;
}

sub create_instance_from_rowhash {
    my ($self, $rowhash) = @_;

    my $tree = new Bio::EnsEMBL::Compara::CAFEGeneFamily;
    $self->SUPER::init_instance_from_rowhash($tree, $rowhash);
    $self->init_instance_from_rowhash($tree, $rowhash);
    return $tree;
}


sub init_instance_from_rowhash {
    my ($self, $node, $rowhash) = @_;

    $node->cafe_gene_family_id($rowhash->{cafe_gene_family_id});
    $node->gene_tree_root_id($rowhash->{gene_tree_root_id});
    $node->lambdas($rowhash->{lambdas});
    $node->lca_id($rowhash->{lca_id});
    $node->pvalue_avg($rowhash->{pvalue_avg});

    $node->adaptor($self);

    return $node;
}


1;
