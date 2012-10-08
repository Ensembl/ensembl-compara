=head1 LICENSE                                                                                                                                                                                
  Copyright (c) 1999-2011 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::DBSQL::CAFEGeneFamilyAdaptor

=head1 SYNOPSIS


=head1 DESCRIPTION

  CAFEGeneFamilyAdaptor - Information about CAFE gene families


=head1 APPENDIX

  The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::CAFEGeneFamilyAdaptor;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Utils::Exception qw/throw warning/;
use Bio::EnsEMBL::Compara::CAFEGeneFamily;

use base ('Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor');

sub fetch_all {
    my ($self) = @_;

    my $constraint = "stn.node_id = str.root_id";
    return $self->generic_fetch($constraint);
}

sub fetch_by_dbID {
    my ($self, $cafe_gene_family_id) = @_;
    unless (defined $cafe_gene_family_id) {
        throw("cafe_gene_family_id must be defined");
    }
    my $constraint = "stn.node_id = str.root_id AND cgf.cafe_gene_family_id = $cafe_gene_family_id";
    my $tree = $self->generic_fetch($constraint);
    if (scalar @$tree > 1) {
        throw("too many trees returned by fetch_by_dbID: Only 1 expected by ", scalar @$tree, " obtained\n");
    }
    return $tree->[0];
}

sub fetch_all_lca_trees {
    my ($self) = @_;
    my $constraint = "stn.node_id = cgf.lca_id";
    my $trees = $self->generic_fetch($constraint);
    # We need to fix the roots:
    for my $tree (@{$trees}) {
        $tree->disavow_parent()
    }
    return $trees;
}

sub fetch_all_with_lca {
    my ($self, $lca) = @_;
    unless (defined $lca) {
        throw("lca must be defined");
    }
    my $constraint = "stn.node_id = str.root_id";
    my $sth = $self->prepare("SELECT node_id FROM species_tree_node_tag WHERE tag ='taxon_id' AND value = ?");
    $sth->execute($lca);
    my ($lca_id) = $sth->fetchrow_array();
    $sth->finish;
    $constraint .= " AND cgf.lca_id = $lca_id";
    return $self->generic_fetch($constraint);
}

sub fetch_lca_tree {
    my ($self, $cafeTree) = @_;

    unless ($cafeTree->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::CAFEGeneFamily] not a $cafeTree");
    }
    my $lca = $cafeTree->lca_id();
#    my $gene_tree_root_id = $cafeTree->gene_tree_root_id;
    my $cafe_gene_family_id = $cafeTree->cafe_gene_family_id;
    my $constraint = "stn.node_id = cgf.lca_id AND cgf.cafe_gene_family_id = $cafe_gene_family_id";

    my $trees = $self->generic_fetch($constraint);
    if (scalar @{$trees} > 1) {
        throw("too many trees fetched by fetch_lca_tree: Only 1 expected but ", scalar @{$trees}, " obtained\n");
    }
    my $tree = $trees->[0];
    $tree->disavow_parent();
    return $tree;
}

sub fetch_by_GeneTree {
    my ($self, $geneTree) = @_;
    return undef unless (defined $geneTree);
    unless ($geneTree->isa('Bio::EnsEMBL::Compara::GeneTree')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::GeneTree] not a $geneTree");
    }
    my $node_id = $geneTree->root_id();

    return $self->fetch_by_gene_tree_root_id($node_id);
}

sub fetch_by_gene_tree_root_id {
    my ($self, $gene_tree_root_id) = @_;
    unless (defined $gene_tree_root_id) {
        throw("gene_tree_root_id must be defined");
    }
    my $constraint = "cgf.gene_tree_root_id = $gene_tree_root_id AND str.root_id = stn.root_id AND csg.node_id = stn.root_id";
    my $trees = $self->generic_fetch($constraint);

    if (scalar @$trees > 1) {
        throw ("Too many trees returned by fetch_by_gene_tree_root_id (only 1 expected)\n");
    }
    return $trees->[0];
}

sub fetch_all_children_for_node {
    my ($self, $node) = @_;

    my $gene_tree_root_id = $node->gene_tree_root_id();

    my $constraint = "parent_id = " . $node->node_id;
    $constraint .= " AND cgf.gene_tree_root_id = $gene_tree_root_id " if (defined $gene_tree_root_id);
    my $kids = $self->generic_fetch($constraint);
    foreach my $child (@{$kids}) { $node->add_child($child); }

    return $node;
}


## Stores a family gene
## Assumes a CAFE species tree already exists
sub store_gene_family {
    my ($self, $root_id, $lca_id, $gene_tree_root_id, $pvalue_avg, $lambdas) = @_;

    my $sth = $self->prepare("INSERT INTO CAFE_gene_family (root_id, lca_id, gene_tree_root_id, pvalue_avg, lambdas) VALUES (?,?,?,?,?)");
    $sth->execute($root_id, $lca_id, $gene_tree_root_id, $pvalue_avg, $lambdas);
    my $cafe_gene_family_id = $sth->{'mysql_insertid'};
    $sth->finish();

    my $sth2 = $self->prepare("SELECT node_id FROM species_tree_node WHERE root_id = ?");
    $sth2->execute($root_id);

    my $sth3 = $self->prepare("SELECT value FROM species_tree_node_tag WHERE node_id = ? and tag = 'taxon_id'");
    my $sth4 = $self->prepare("INSERT INTO CAFE_species_gene (cafe_gene_family_id, node_id, taxon_id, n_members, pvalue) VALUES (?,?,?,?,?)");

    while (my ($node_id) = $sth2->fetchrow_array) {
        ## Substitute for get_tagvalue
        $sth3->execute($node_id);
        my ($taxon_id) = $sth3->fetchrow_array();
        $sth4->execute($cafe_gene_family_id, $node_id, $taxon_id, 0, 1);
    }

    $sth2->finish();
    $sth3->finish();
    $sth4->finish();

    return $cafe_gene_family_id;
}

sub store_species_gene {
    my ($self, $cafe_gene_family_id, $node_id, $taxon_id, $n_members, $pvalue) = @_;
    my $sth = $self->prepare("UPDATE CAFE_species_gene SET n_members = ?, pvalue = ? WHERE cafe_gene_family_id = ? AND node_id = ?");
#    my $sth = $self->prepare("INSERT INTO CAFE_species_gene (cafe_gene_family_id, node_id, taxon_id, n_members, pvalue) VALUES (?,?,?,?,?)");
    $sth->execute($n_members, $pvalue, $cafe_gene_family_id, $node_id);
    $sth->finish();
    return;
}

## Stores the CAFE species tree
sub store_tree {
    my ($self, $tree) = @_;

    # Store the root node
    my $root_id = $self->store_node($tree->root);
    $tree->{'_root_id'} = $root_id;

    # Store the rest of the nodes
    for my $child (@{$tree->get_all_nodes}) {
        $self->store_node($child);
    }

    # Store the tree itself
    # method_link_species_set_id must be set to its real value to honour the foreign key
    my $sth = $self->prepare('INSERT INTO species_tree_root (root_id, method_link_species_set_id, species_tree, pvalue_lim) VALUES (?,?,?,?)');
    $sth->execute($root_id, $tree->method_link_species_set_id, $tree->species_tree, $tree->pvalue_lim);

    $tree->adaptor($self);
    return $root_id;
}

# Stores CAFE species tree's nodes
sub store_node {
    my ($self, $node) = @_;

    unless ($node->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::CAFETreeNode] not a $node");
    }

    if (defined $node->adaptor &&
        $node->adaptor->isa('Bio::EnsEMBL::Compara::DBSQL::CAFEGeneFamilyAdaptor') &&
        $node->adaptor eq $self) {
        # update node
        $self->update($node);
        $node->adaptor($self);
        return;
    }

    my $root_id = $node->root->node_id();

    my $parent_id = 0;
    if ($node->parent()) {
        $parent_id = $node->parent->node_id;
    }

    my $sth = $self->prepare("INSERT INTO species_tree_node(parent_id, root_id, left_index, right_index, distance_to_parent) VALUES (?,?,?,?,?)");
    $sth->execute($parent_id, $root_id, $node->left_index, $node->right_index, $node->distance_to_parent);
    $node->node_id($sth->{'mysql_insertid'});

    ### TODO: use TagAdaptor interface to include these tags
    my $sth2 = $self->prepare("INSERT INTO species_tree_node_tag(node_id, tag, value) VALUES (?,?,?)");

    $node->adaptor($self);
    if ($node->is_leaf) {
        my $name = $node->name;
         $name =~ s/\./_/g;
         my $genomeDB_Adaptor = $self->db->get_GenomeDBAdaptor;
         my $genomeDB = $genomeDB_Adaptor->fetch_by_name_assembly($name);
         my $taxon_id = $genomeDB->taxon_id();
        $sth2->execute($node->node_id, 'taxon_id', $taxon_id);
    } else {
        $sth2->execute($node->node_id, 'taxon_id', $node->name);
    }
    $sth->finish();
    $sth2->finish();

    return $node->node_id
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

               csg.taxon_id
               csg.n_members
               csg.pvalue

               str.root_id
               str.method_link_species_set_id
               str.species_tree
               str.pvalue_lim

               stn.node_id
               stn.parent_id
               stn.left_index
               stn.right_index
               stn.distance_to_parent
             );
}

sub _tables {
    return (['species_tree_node', 'stn'], ['CAFE_gene_family', 'cgf'], ['CAFE_species_gene', 'csg'], ['species_tree_root', 'str']);
}

sub _default_where_clause {
    return "stn.node_id = csg.node_id";
}

sub _left_join {
    return (['CAFE_gene_family', 'cgf.root_id = str.root_id'], ['CAFE_species_gene', 'csg.cafe_gene_family_id=cgf.cafe_gene_family_id']);
}

sub create_instance_from_rowhash {
    my ($self, $rowhash) = @_;
    my $node = new Bio::EnsEMBL::Compara::CAFEGeneFamily;

    $self->init_instance_from_rowhash($node,$rowhash);
    return $node;
}

sub init_instance_from_rowhash {
    my ($self, $node, $rowhash) = @_;

    # SUPER is NestedSetAdaptor
    $self->SUPER::init_instance_from_rowhash($node, $rowhash);

    $node->cafe_gene_family_id($rowhash->{cafe_gene_family_id});
    $node->method_link_species_set_id($rowhash->{method_link_species_set_id});
    $node->species_tree($rowhash->{species_tree});
    $node->pvalue_lim($rowhash->{pvalue_lim});
    $node->gene_tree_root_id($rowhash->{gene_tree_root_id});
    $node->lambdas($rowhash->{lambdas});
    $node->pvalue_avg($rowhash->{pvalue_avg});
    $node->pvalue($rowhash->{pvalue});
    $node->taxon_id($rowhash->{taxon_id});
    $node->n_members($rowhash->{n_members});
    $node->lca_id($rowhash->{lca_id});

    $node->adaptor($self);
    return $node;
}

1;
