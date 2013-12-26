=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::CAFEGeneFamilyAdaptor

=head1 SYNOPSIS


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
use Bio::EnsEMBL::Utils::SqlHelper;
use DBI qw(:sql_types);

use Bio::EnsEMBL::Compara::CAFEGeneFamilyNode;

use base ('Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeNodeAdaptor');

sub store {
    my ($self, $node, $cafe_gene_family_id) = @_;

    # $self->SUPER::store_node($node, $mlss_id);
    $self->store_node($node, $cafe_gene_family_id);
    for my $node(@{$node->children()}) {
        $self->store($node, $cafe_gene_family_id)
    }
    return $node->node_id;
}

sub store_node {
    my ($self, $node, $cafe_gene_family_id) = @_;

    my $sth = $self->prepare("INSERT INTO CAFE_species_gene (cafe_gene_family_id, node_id, n_members, pvalue) VALUES (?,?,?,?)");
    # print STDERR "INSERT INTO CAFE_species_gene (cafe_gene_family_id, node_id, n_members, pvalue) VALUES ($cafe_gene_family_id, " , $node->node_id, ", ", $node->n_members, ", ", $node->pvalue , ")\n";

    $sth->execute($cafe_gene_family_id, $node->node_id, $node->n_members || 0, $node->pvalue || 1);
    $sth->finish;
    return;

}

sub _columns {
    return qw (
                  str.root_id

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
                  csg.node_id
             );
}

sub _tables {
    return (['CAFE_species_gene', 'csg'], ['species_tree_node', 'stn'], ['species_tree_root', 'str'] );
}

sub _left_join {
    return (['species_tree_node', 'stn.node_id=csg.node_id']);
}

sub create_instance_from_rowhash {
    my ($self, $rowhash) = @_;
    my $node = new Bio::EnsEMBL::Compara::CAFEGeneFamilyNode;

    $self->init_instance_from_rowhash($node, $rowhash);
    return $node;
}

sub init_instance_from_rowhash {
    my ($self, $node, $rowhash) = @_;

    $self->SUPER::init_instance_from_rowhash($node, $rowhash);
    $node->cafe_gene_family_id($rowhash->{cafe_gene_family_id});
    $node->n_members($rowhash->{n_members});
    $node->pvalue($rowhash->{pvalue});

    $node->adaptor($self);
}

sub fetch_tree_by_cafe_gene_family_id {
    my ($self, $cafe_gene_family_id) = @_;
    my $table = ($self->_tables)[0]->[1];
    my $constraint = "$table.cafe_gene_family_id = ?";
    $self->bind_param_generic_fetch($cafe_gene_family_id, SQL_INTEGER);
    my $nodes = $self->generic_fetch($constraint);
    my $tree = $self->_build_tree_from_nodes($nodes);
    return $tree;
}


1;
