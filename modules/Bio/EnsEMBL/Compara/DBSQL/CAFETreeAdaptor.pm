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

Bio::EnsEMBL::Compara::DBSQL::GeneTreeNodeAdaptor

=head1 SYNOPSIS

=head1 DESCRIPTION

CAFETreeAdaptor - Generic adaptor for a CAFE tree with information about the tree and the expansion / contraction of each family.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::CAFETreeAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::DBSQL::CAFETreeAdaptor;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Utils::Exception qw/throw warning/;
use Bio::EnsEMBL::Compara::CAFETreeNode;

use base ('Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor');


###################################
# FETCH METHODS
###################################

=head2 fetch_all

  Arg[1]      : -none-
  Example     : $all_cafe_trees = $CAFEtree_adaptor->fetch_all();

  Description : Fetches all the CAFE trees from the database.
  Returntype  : arrayref of Bio::EnsEMBL::Compara::CAFETreeNode
  Exceptions  : none
  Caller      :

=cut

sub fetch_all {
    my ($self) = @_;
    my $constraint = "ctn.node_id = ct.root_id";
    return $self->generic_fetch($constraint);
}

=head2 fetch_by_GeneTree

  Arg[1]      : Bio::EnsEMBL::Compara::GeneTree
  Example     : $cafe_tree = $CAFEtree_adaptor->fetch_by_GeneTree();

  Description : Fetches the CAFE tree from the database that contains the GeneTree
                specified as input.
  ReturnType  : Bio::EnsEMBL::Compara::CAFETreeNode
  Exceptions  : <>
  Caller      : <>

=cut

sub fetch_by_GeneTree {
    my ($self, $genetree) = @_;
    unless ($genetree->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::GeneTreeNode] not a $genetree");
    }

    my $node_id = $genetree->node_id();  # root_id?

    return $self->fetch_by_family_id($node_id);
}

sub fetch_all_children_for_node {
    my ($self, $node) = @_;
    my $fam_id = $node->fam_id();

    my $constraint = "parent_id = " . $node->node_id;
    $constraint .= " AND cta.fam_id = $fam_id " if defined $fam_id;
    my $kids = $self->generic_fetch($constraint);
    foreach my $child (@{$kids}) { $node->add_child($child); }

    return $node;
}

=head2 fetch_by_family_id

  Arg[1]      : Integer representing a family_id
  Example     : $cafe_tree = $CAFEtree_adaptor->fetch_by_familyId(893);

  Description : Fetches a CAFE tree from the database that contains the specified family_id
  ReturnType  : Bio::EnsEMBL::Compara::CAFETreeNode
  Exceptions  :
  Caller      :

=cut

sub fetch_by_family_id {
    my ($self, $fam_id) = @_;
    unless (defined $fam_id) {
        throw("fam_id is undefined");
    }
    my $constraint = "cta.fam_id=$fam_id AND ctn.node_id = ctn.root_id";
    my $trees = $self->generic_fetch($constraint);
    if (scalar @$trees > 1) {
        throw ("Many trees returned by fetch_by_family_id (only 1 expected)\n");
    }
    return $trees->[0];
}


###########################
# STORE methods
###########################

sub store {
    my ($self, $node) = @_;

    unless ($node->isa('Bio::EnsEMBL::Compara::CAFETreeNode')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::CAFETreeNode] not a $node");
    }

    my $root_id = $self->store_node($node);

    # First, insert the corresponding CAFE_tree if it is not there
    my $mlss_id = $node->method_link_species_set_id();
    if (defined $mlss_id) {
        my $species_tree = $node->species_tree();
        my $lambdas = $node->lambdas();
        my $pvalue_lim = $node->pvalue_lim();

        my $sth2 = $self->prepare("INSERT INTO CAFE_tree(root_id, method_link_species_set_id, species_tree, lambdas, p_value_lim) VALUES(?,?,?,?,?)");
        $sth2->execute($root_id, $mlss_id, $species_tree, $lambdas, $pvalue_lim);
        $sth2->finish();
    }

    $node->build_leftright_indexing();

    # recursively do all the children
    my $children = $node->children;
    for my $child_node (@$children) {
        $self->store($child_node);
    }
    return $node->node_id;
}

sub store_node {
    my ($self, $node) = @_;
    unless ($node->isa('Bio::EnsEMBL::Compara::CAFETreeNode')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::CAFETreeNode] not a $node'");
    }

    if (defined $node->adaptor &&
        $node->adaptor->isa('Bio::EnsEMBL::Compara::DBSQL::CAFETreeAdaptor') &&
        $node->adaptor eq $self) {
        # already in the database, so just update
#        print STDERR "Updating ", $node->name, "\n";
        return $self->update_node($node);
    }

    my $root_id = $node->root->node_id();

#    print STDERR "root_id for node " . $node->node_id . " is $root_id\n";
    my $parent_id = 0;
    if ($node->parent()) {
        $parent_id = $node->parent->node_id();
    }

    my $sth = $self->prepare("INSERT INTO CAFE_tree_node(parent_id, root_id, left_index, right_index, distance_to_parent) VALUES(?,?,?,?,?)");
    $sth->execute($parent_id, $root_id, $node->left_index, $node->right_index, $node->distance_to_parent);
    $node->node_id( $sth->{'mysql_insertid'} ); # Where is this comming from?
    $node->adaptor($self);
    $sth->finish();

#    print "NODE_ID: " . $node->node_id() . " => PARENT_ID: $parent_id\n";

    if ($parent_id == 0) { # this is a root node
#        print STDERR ">>>>>>>>>>>>Updating Root for Root node<<<<<<<<<<<<<<\n";
        $sth = $self->prepare("UPDATE CAFE_tree_node SET root_id = ? WHERE node_id = ?");
        $sth->execute($node->node_id, $node->node_id);
        $sth->finish();
    }

    return $node->node_id;
}

sub update_node {
    my ($self, $node) = @_;

    # We don't update CAFE_tree (only CAFE_tree_node)

    unless ($node->isa('Bio::EnsEMBL::Compara::CAFETreeNode')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::CAFETreeNode] not a $node'");
    }

    my ($parent_id, $root_id) = (0,0);

    if ($node->parent()) {
        $parent_id = $node->parent->node_id;
        if (ref($node->node_id)) {
            $root_id = $node->root->node_id();
        } else {
            $root_id = $node->subroot->node_id();
        }
    }

    my $sth = $self->prepare("UPDATE CAFE_tree_node SET
                             parent_id=?,
                             root_id=?,
                             left_index=?,
                             right_index=?,
                             distance_to_parent=?
                             WHERE node_id=?");
    $sth->execute($parent_id,
                  $root_id,
                  $node->left_index,
                  $node->right_index,
                  $node->distance_to_parent,
                  $node->node_id);

    $node->adaptor($self);
    $sth->finish();
}


###################################
#
# tagging
#
###################################

sub _load_tagvalues {
    my ($self, $node) = @_;

    unless ($node->isa('Bio::EnsEMBL::Compara::CAFETreeNode')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::CAFETreeNode] not a $node'");
    }

    # Updates the list of attribute names
    if (not exists $self->{'_attr_list'}) {
        $self->{'_attr_list'} = {};
        eval {
            my $sth = $self->dbc->db_handle->column_info(undef, undef, "CAFE_tree_attr", '%');
            $sth->execute();
            while (my $row = $sth->fetchrow_hashref()) {
                ${$self->{'_attr_list'}}{${$row}{'COLUMN_NAME'}} = 1;
            }
            $sth->finish;
        };
        if ($@) {
            warn "CAFE_tree_attr not available in this database\n";
        }
    }

    # Attributes (multiple values are forbidden)
    if (%{$self->{'_attr_list'}}) {  # Only if some attributes are defined
        my $sth = $self->prepare("SELECT * FROM CAFE_tree_attr WHERE node_id=?");
        $sth->execute($node->node_id);
        # Retrieve data
        my $attrs = $sth->fetchrow_hashref();
        if (defined $attrs) {
            foreach my $key (keys %$attrs) {
                if (($key ne 'node_id') and defined(${$attrs}{$key})) {
                    $node->add_tag($key, ${$attrs}{$key});
                }
            }
        }
        $sth->finish;
    }
}

sub store_tagvalues {
    my ($self, $node, $fam_id, $taxon_id, $n_members, $p_value, $avg_pvalue) = @_;
    my $sth = $self->prepare("INSERT INTO CAFE_tree_attr VALUES(?,?,?,?,?,?)");
    $sth->execute($node->node_id, $fam_id, $taxon_id, $n_members, $p_value, $avg_pvalue);
    $sth->finish();
    return;
}


sub _store_tagvalue {
    my ($self, $node_id, $tag, $value) = @_;

#    print STDERR "ATTR_LIST: ", Dumper $self->{'_attr_list'}, "\n";

#    unless (defined $self->{'_attr_list'} && exists $self->{'_attr_list'}->{$tag}) {
#        throw("$tag is not a valid attribute for $self");
#    }

    my $sth = $self->prepare("INSERT IGNORE INTO CAFE_tree_attr(node_id) VALUES(?)");
    $sth->execute($node_id);
    $sth->finish();
    $sth = $self->prepare("UPDATE IGNORE CAFE_tree_attr SET $tag=? WHERE node_id=?");
    $sth->execute($value, $node_id);
    $sth->finish();
}

sub _delete_tagvalue {
    my ($self, $node_id, $tag, $value) = @_;

    unless (defined $self->{'attr_list'} && exists $self->{'attr_list'}->{$tag}) {
        throw("$tag is not a valid attribute for $self");
    }

    my $sth = $self->prepare("UPDATE CAFE_tree_attr SET $tag=NULL WHERE node_id=?");
    $sth->execute($node_id);
    $sth->finish();
}


##################################
#
# subclass override methods
#
##################################

sub _columns {
    return qw(ctn.node_id
            ctn.parent_id
            ctn.root_id
            ctn.left_index
            ctn.right_index
            ctn.distance_to_parent

            ct.method_link_species_set_id
            ct.species_tree
            ct.lambdas
            ct.p_value_lim

            cta.fam_id
            cta.taxon_id
            cta.n_members
            cta.p_value
            cta.avg_pvalue
           );
}

sub _tables {
    return (['CAFE_tree_attr', 'cta'], ['CAFE_tree_node', 'ctn']);
}

sub _default_left_join_clause {
    return "LEFT JOIN CAFE_tree ct ON (ctn.node_id = ct.root_id) ";
}

sub _default_where_clause {
    return "cta.node_id = ctn.node_id"
}

sub _get_starting_lr_index {
    return 1;
}


sub create_instance_from_rowhash {
    my ($self, $rowhash) = @_;

    my $node = new Bio::EnsEMBL::Compara::CAFETreeNode;

    $self->init_instance_from_rowhash($node, $rowhash);
    return $node;
}

sub init_instance_from_rowhash {
    my ($self, $node, $rowhash) = @_;

    # SUPER is NestedSet
    $self->SUPER::init_instance_from_rowhash($node, $rowhash);

    $node->method_link_species_set_id($rowhash->{method_link_species_set_id});
    $node->species_tree($rowhash->{species_tree});
    $node->lambdas($rowhash->{lambdas});
    $node->avg_pvalue($rowhash->{avg_pvalue});
    $node->p_value($rowhash->{p_value});
    $node->taxon_id($rowhash->{taxon_id});
    $node->n_members($rowhash->{n_members});
    $node->fam_id($rowhash->{fam_id});
    $node->pvalue_lim($rowhash->{p_value_lim});

    $node->adaptor($self);
    return $node;
}

1;
