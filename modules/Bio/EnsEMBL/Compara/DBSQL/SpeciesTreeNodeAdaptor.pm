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

Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeNodeAdaptor

=head1 DESCRIPTION

  SpeciesTreeNodeAdaptor - Adaptor for different species trees used in ensembl-compara


=head1 APPENDIX

  The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeNodeAdaptor;

use strict;
use warnings;
use Data::Dumper;


use Bio::EnsEMBL::Compara::SpeciesTreeNode;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use base ('Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');

=head2 new_from_NestedSet

    Arg[1]      : An object that inherits from NestedSet
    Arg[2](opt) : A method in the object to obtain the TaxonID in the non-leaf nodes (defaults to "name");
    Example     : my $st_node = Bio::EnsEMBL::Compara::SpeciesTreeNode->new_from_NestedSet($tree);
    Description : Constructor for species tree nodes. Given an object that inherits from NestedSet (possibly a tree), creates a new SpeciesTreeNode (possibly a tree).
    ReturnType  : EnsEMBL::Compara::SpeciesTreeNode
    Exceptions  : none
    Caller      : General

=cut

sub new_from_NestedSet {
    my ($self, $nestedSet_tree, $name_method, $taxon_id_method) = @_;
    # It would be better if name_method and taxon_id_method are callbacks
    # (or callbacks are allowed?)

    $name_method = $name_method || "name";
    $taxon_id_method = $taxon_id_method || "taxon_id";

    my $genomeDB_Adaptor = $self->db->get_GenomeDBAdaptor;
    my $NCBITaxon_Adaptor = $self->db->get_NCBITaxonAdaptor;

    my $tree = $nestedSet_tree->cast('Bio::EnsEMBL::Compara::SpeciesTreeNode');
    for my $node (@{$tree->get_all_nodes}) {
        my $name = $node->$name_method;
        my $taxon_id = $node->$taxon_id_method;
        if ($node->is_leaf) {
            if (defined $taxon_id) {
                $node->taxon_id($taxon_id);
            }
            if (defined $name) {
                $node->node_name($name);
            }

            my $genomeDB;
            if ($node->genome_db_id) {
                $genomeDB = $genomeDB_Adaptor->fetch_by_dbID($node->genome_db_id);
            } elsif (defined $node->taxon_id) {
                $genomeDB = $genomeDB_Adaptor->fetch_by_taxon_id($node->taxon_id);
            } elsif (defined $node->node_name) {
                $genomeDB = $genomeDB_Adaptor->fetch_by_name_assembly($node->node_name);
            }
            if (defined $genomeDB) {
                $node->genome_db_id($genomeDB->dbID);
                $node->taxon_id($genomeDB->taxon_id)
            }

        } else {
            my $taxon_node;
            if (defined $taxon_id) {
                $taxon_node = $NCBITaxon_Adaptor->fetch_node_by_taxon_id($taxon_id)
            } elsif (defined $name) {
                $taxon_node = $NCBITaxon_Adaptor->fetch_node_by_name($name);
            }
            if (defined $taxon_node) {
                $node->taxon_id($taxon_node->taxon_id);
            }
        }
    }
    return $tree;
}


## TODO: This is very similar to GeneTreeNodeAdaptor's store_nodes_rec, maybe we can
## abstract out this code in NestedSetAdaptor
sub store {
    my ($self, $node, $mlss_id) = @_;

    $self->store_node($node, $mlss_id);
    for my $node(@{$node->children()}) {
        $self->store($node, $mlss_id); ## We don't need to include here mlss_id since this is never the root node
    }
    return $node->node_id;
}

## TODO: This is very similar to GeneTreeNodeAdaptor's store_node, maybe we can
## abstract out this code in NestedSetAdaptor
sub store_node {
    my ($self, $node, $mlss_id) = @_;

## This may fail in the case of CAFEGeneFamilyNodes
    assert_ref($node, 'Bio::EnsEMBL::Compara::SpeciesTreeNode');

    if (not($node->adaptor and $node->adaptor->isa('Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeNodeAdaptor') and $node->adaptor eq $self)) {

        my $count_current_rows = $self->dbc->db_handle->selectall_arrayref("SELECT COUNT(*) FROM species_tree_node")->[0]->[0];

        my $node_id;
        if ($count_current_rows) {
            my $sth1 = $self->prepare("INSERT INTO species_tree_node VALUES ()");
            $sth1->execute();
            $node_id = $self->dbc->db_handle->last_insert_id(undef, undef, 'species_tree_node', 'node_id');
            $sth1->finish();

        } else {
            ## if table is empty then $node_id should be mlss_id * 1000
            $node_id = $mlss_id * 1000;
            my $sth3 = $self->prepare("INSERT INTO species_tree_node (node_id) VALUES (?)");
            $sth3->execute($node_id);
            $sth3->finish();
        }

        $node->node_id( $node_id );
    }

    my $parent_id = $node->parent->node_id if($node->parent);
    my $root_id = $node->root->node_id;

    my $node_name = $node->node_name || $node->name;
    my ($taxon_id, $genome_db_id);

    $taxon_id = $node->taxon_id;
    $genome_db_id = $node->genome_db_id;

    my $sth = $self->prepare("UPDATE species_tree_node SET parent_id=?, root_id=?, left_index=?, right_index=?, distance_to_parent=?, taxon_id=?, genome_db_id=?, node_name=? WHERE node_id=?");
    $sth->execute($parent_id, $root_id, $node->left_index, $node->right_index, $node->distance_to_parent, $taxon_id, $genome_db_id, $node_name, $node->node_id);
    $sth->finish;

    return $node->node_id;
}


#
# tagging
#
sub _tag_capabilities {
    return ('species_tree_node_tag', undef, 'node_id', 'node_id');
}


#################################################
#
# subclass override methods
#
#################################################

sub _columns {
    return qw ( stn.node_id
                stn.root_id
                stn.parent_id
                stn.left_index
                stn.right_index
                stn.distance_to_parent
                stn.taxon_id
                stn.genome_db_id
                stn.node_name
             );
}

sub _tables {
    return (['species_tree_node', 'stn'], ['species_tree_root','str']);
}

sub _default_where_clause {
    return "stn.root_id = str.root_id";
}

sub create_instance_from_rowhash {
    my ($self, $rowhash) = @_;

    my $node = new Bio::EnsEMBL::Compara::SpeciesTreeNode;

    $self->init_instance_from_rowhash($node, $rowhash);
    return $node;
}

sub init_instance_from_rowhash {
    my ($self, $node, $rowhash) = @_;

    # SUPER is NestedSetAdaptor
    $self->SUPER::init_instance_from_rowhash($node, $rowhash);

    $node->taxon_id($rowhash->{'taxon_id'});
    $node->genome_db_id($rowhash->{'genome_db_id'});
    $node->node_name($rowhash->{'node_name'});

    $node->adaptor($self);
    return $node;
}

1;
