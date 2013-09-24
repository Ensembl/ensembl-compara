=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeNodeAdaptor

=head1 SYNOPSIS


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

use base ('Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor');


## TODO: This is very similar to GeneTreeNodeAdaptor's store_nodes_rec, maybe we can
## abstract out this code in NestedSetAdaptor
sub store {
    my ($self, $node, $mlss_id) = @_;

    $self->store_node($node, $mlss_id);
    for my $node(@{$node->children()}) {
        $self->store($node); ## We don't need to include here mlss_id since this is never the root node
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
        my $sth1 = $self->prepare("INSERT INTO species_tree_node VALUES ()");
        $sth1->execute();
        my $node_id = $sth1->{'mysql_insertid'};
        $sth1->finish();
        ## $node_id is 1 if table is empty then $node_id should be mlss_id * 1000
        if ($node_id == 1) {
            $node_id = $mlss_id * 1000;
            my $sth2 = $self->prepare("TRUNCATE species_tree_node");
            $sth2->execute();
            $sth2->finish();
            my $sth3 = $self->prepare("INSERT INTO species_tree_node (node_id) VALUES (?)");
            $sth3->execute($node_id);
            $sth3->finish();
        }

        $node->node_id( $node_id );
        $sth1->finish();
    }

    my $parent_id = $node->parent->node_id if($node->parent);
    my $root_id = $node->root->node_id();

    my $node_name = $node->name;
    my ($taxon_id, $genome_db_id);

    $taxon_id = $node->taxon_id;
    $genome_db_id = $node->genome_db_id;

    my $sth = $self->prepare("UPDATE species_tree_node SET parent_id=?, root_id=?, left_index=?, right_index=?, distance_to_parent=?, taxon_id=?, genome_db_id=?, node_name=? WHERE node_id=?");
    $sth->execute($parent_id, $root_id, $node->left_index, $node->right_index, $node->distance_to_parent, $taxon_id, $genome_db_id, $node_name, $node->node_id);
    $sth->finish;

    return $node->node_id;
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
