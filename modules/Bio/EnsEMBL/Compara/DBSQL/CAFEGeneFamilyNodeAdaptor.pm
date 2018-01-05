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

  CAFEGeneFamilyNodeAdaptor - Information about CAFE gene family nodes


=head1 APPENDIX

  The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::CAFEGeneFamilyNodeAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use DBI qw(:sql_types);

use Bio::EnsEMBL::Compara::CAFEGeneFamilyNode;
use Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


########################
# Store/update methods #
########################

sub store_node {
    my ($self, $node, $cafe_gene_family_id) = @_;

    $self->generic_insert('CAFE_species_gene', {
            'cafe_gene_family_id'   => $cafe_gene_family_id,
            'node_id'               => $node->node_id,
            'n_members'             => $node->n_members || 0,
            'pvalue'                => $node->pvalue,
        } );
}


############################################################
# Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor implementation #
############################################################

sub _columns {
    return qw (
                  stn.node_id
                  stn.parent_id
                  stn.root_id
                  stn.left_index
                  stn.right_index
                  stn.distance_to_parent
                  stn.taxon_id
                  stn.genome_db_id
                  stn.node_name

                  csg.cafe_gene_family_id
                  csg.n_members
                  csg.pvalue
             );
}

sub _tables {
    return (['CAFE_species_gene', 'csg'], ['species_tree_node', 'stn']);
}

sub _default_where_clause {
    return 'stn.node_id=csg.node_id';
}

sub _objs_from_sth {
    my ($self, $sth) = @_;
    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::CAFEGeneFamilyNode', [
            '_node_id',
            '_parent_id',
            '_root_id',
            '_left_index',
            '_right_index',
            '_distance_to_parent',
            '_taxon_id',
            '_genome_db_id',
            '_node_name',

            '_cafe_gene_family_id',
            '_n_members',
            '_pvalue',
        ] );
}


#################
# Fetch methods #
#################


=head2 fetch_tree_by_cafe_gene_family_id

  Example     : $cafe_gene_family_node_adaptor->fetch_tree_by_cafe_gene_family_id();
  Description : Fetch all the nodes for the given family dbID and assemble them
                into a tree structure. Returns the root node
  Returntype  : Bio::EnsEMBL::Compara::CAFEGeneFamilyNode
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_tree_by_cafe_gene_family_id {
    my ($self, $cafe_gene_family_id) = @_;
    my $table = ($self->_tables)[0]->[1];
    my $constraint = "$table.cafe_gene_family_id = ?";
    $self->bind_param_generic_fetch($cafe_gene_family_id, SQL_INTEGER);
    my $nodes = $self->generic_fetch($constraint);
    my $tree = Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor->_build_tree_from_nodes($nodes);
    return $tree;
}


1;
