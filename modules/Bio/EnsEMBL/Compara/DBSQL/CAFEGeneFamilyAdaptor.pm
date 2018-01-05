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

Bio::EnsEMBL::Compara::DBSQL::CAFEGeneFamilyAdaptor

=head1 DESCRIPTION

  CAFEGeneFamilyAdaptor - Information about CAFE gene families


=head1 APPENDIX

  The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::CAFEGeneFamilyAdaptor;

use strict;
use warnings;

use DBI qw(:sql_types);

use Bio::EnsEMBL::Compara::CAFEGeneFamily;
use Bio::EnsEMBL::Compara::Utils::Scalar qw(:assert);

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


#################
# Fetch methods #
#################

=head2 fetch_by_GeneTree

  Arg[1]      : Bio::EnsEMBL::Compara::GeneTree $geneTree
  Example     : $cafe_gene_family_adaptor->fetch_by_GeneTree($gene_tree);
  Description : Returns the CAFEGeneFamily object summarizing the given GeneTree.
                Not all the (default) gene-trees will have a CAFEGeneFamily, so you
                need to expect this method to return undef at times. Moreover,
                the CAFE analysis is only run for default trees, so calling this
                method on an intermediate tree (i.e. ref_root_id is defined) will
                return the CAFEGeneFamily of the reference tree.
  Returntype  : Bio::EnsEMBL::Compara::CAFEGeneFamily
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_by_GeneTree {
    my ($self, $geneTree) = @_;

    assert_ref_or_dbID($geneTree, 'Bio::EnsEMBL::Compara::GeneTree', 'geneTree');
    my $root_id = ref($geneTree) ? ($geneTree->ref_root_id() || $geneTree->root_id()) : $geneTree;

    my $constraint = 'cgf.gene_tree_root_id = ?';
    $self->bind_param_generic_fetch($root_id, SQL_INTEGER);

    return $self->generic_fetch_one($constraint);
}


=head2 fetch_all_by_method_link_species_set_id

  Arg[1]      : Integer $mlss_id
  Example     : $cafe_gene_family_adaptor->fetch_all_by_method_link_species_set_id();
  Description : Returns all the CAFEGeneFamily objects associated to the
                given MethodLinkSpeciesSet
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::CAFEGeneFamily
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_by_method_link_species_set_id {
    my ($self, $mlss_id) = @_;

    # mlss_id is not stored in the CAFE_gene_family table, so we first find
    # it in the species_tree_root table
    my $species_tree_adaptor = $self->db->get_SpeciesTreeAdaptor;
    my $species_tree = $species_tree_adaptor->fetch_by_method_link_species_set_id_label($mlss_id, 'cafe');
    my $root_id = $species_tree->root->node_id();

    # And then we fetch all the CAFEGeneFamily attached to that (species_tree_)root_id
    my $constraint = 'str.root_id = ?';
    $self->bind_param_generic_fetch($root_id, SQL_INTEGER);
    return $self->generic_fetch($constraint);
}


########################
# Store/update methods #
########################

sub store {
    my ($self, $tree) = @_;

    # First store the header and grab a new dbID
    my $cafe_gene_family_id = $self->generic_insert('CAFE_gene_family', {
            'root_id'           => $tree->root->node_id,
            'lca_id'            => $tree->lca_id,
            'gene_tree_root_id' => $tree->gene_tree_root_id,
            'pvalue_avg'        => $tree->pvalue_avg,
            'lambdas'           => $tree->lambdas,
        }, 'cafe_gene_family_id' );

    $self->attach($tree, $cafe_gene_family_id);

    # Then store the nodes
    my $cafe_gene_family_node_adaptor = $self->db->get_CAFEGeneFamilyNodeAdaptor();
    foreach my $node (@{$tree->root->get_all_nodes}) {
        $cafe_gene_family_node_adaptor->store_node($node, $cafe_gene_family_id);
    }

    return $cafe_gene_family_id;
}


############################################################
# Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor implementation #
############################################################

sub _columns {
    return qw (cgf.cafe_gene_family_id
               cgf.root_id
               cgf.lca_id
               cgf.pvalue_avg
               cgf.lambdas
               cgf.gene_tree_root_id

               str.method_link_species_set_id
               str.label
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
    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::CAFEGeneFamily', [
            '_cafe_gene_family_id',
            '_root_id',
            '_lca_id',
            '_pvalue_avg',
            '_lambdas',
            '_gene_tree_root_id',
            '_method_link_species_set_id',
            '_label',
        ] );
}


1;
