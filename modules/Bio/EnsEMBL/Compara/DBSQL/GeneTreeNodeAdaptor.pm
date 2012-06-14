=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
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

=head1 DESCRIPTION

Adaptor to retrieve nodes of gene trees

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::GeneTreeNodeAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor
  `- Bio::EnsEMBL::Compara::DBSQL::TagAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::DBSQL::GeneTreeNodeAdaptor;

use strict;
no strict 'refs';

use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::GeneTreeNode;
use Bio::EnsEMBL::Compara::GeneTreeMember;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;

use DBI qw(:sql_types);

use base ('Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');

###########################
# FETCH methods
###########################

=head2 fetch_all

  Description: DEPRECATED. Use GeneTreeAdaptor::fetch_all(-tree_type=>"tree") instead
                            (possibly with a -member_type option)

=cut

# This function must stay here to override the one from NestedSetAdaptor
sub fetch_all {
    my $self = shift;
    deprecate('See Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor::fetch_all(-tree_type=>"tree") instead (possibly with a member_type constraint)');
    return $self->_extract_roots_from_trees($self->db->get_GeneTreeAdaptor->fetch_all(-tree_type => 'tree'));
}


=head2 fetch_all_roots

  Description: DEPRECATED. Use GeneTreeAdaptor::fetch_all(-tree_type=>"clusterset") instead
                            (possibly with a -member_type option)

=cut

sub fetch_all_roots {
    my $self = shift;
    deprecat_('See Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor::fetch_all(-tree_tproteinype=>"clusterset") instead (possibly with a member_type constraint)');
    return $self->_extract_roots_from_trees($self->db->get_GeneTreeAdaptor->fetch_all(-tree_type => 'clusterset'));
}


=head2 fetch_by_Member_root_id

  Description: DEPRECATED. Use GeneTreeAdaptor::fetch_all_by_Member() instead
                            (possibly with a -clusterset_id option)

=cut

sub fetch_by_Member_root_id {
    my ($self, $member, $clusterset_id) = @_;
    deprecate('Use Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor::fetch_all_by_Member instead');
    return $self->_extract_roots_from_trees($self->db->get_GeneTreeAdaptor->fetch_all_by_Member($member, -clusterset_id => $clusterset_id))->[0];
}


=head2 fetch_by_gene_Member_root_id

  Description: DEPRECATED. Use GeneTreeAdaptor::fetch_all_by_Member() instead
                            (possibly with a -clusterset_id option)

=cut

sub fetch_by_gene_Member_root_id {
    my ($self, $member, $clusterset_id) = @_;
    deprecate('Use Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor::fetch_all_by_Member instead');
    return $self->_extract_roots_from_trees($self->db->get_GeneTreeAdaptor->fetch_all_by_Member($member, -clusterset_id => $clusterset_id))->[0];
}


=head2 fetch_all_AlignedMember_by_Member

  Arg[1]     : Member or member_id
  Arg [-METHOD_LINK_SPECIES_SET] (opt)
             : MethodLinkSpeciesSet or int: either the object or its dbID
  Arg [-CLUSTERSET_ID] (opt)
             : int: the root_id of the clusterset node
               NB: The definition of this argument is unstable and might change
                   in the future
  Example    : $all_members = $genetree_adaptor->fetch_all_AlignedMember_by_Member($member);
  Description: Transforms the member into an AlignedMember. If the member is
               not an ENSEMBLGENE, it has to be canoncal, otherwise, the
               function would return an empty array
               NB: This function currently returns an array of at most 1 element
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_AlignedMember_by_Member {
    my ($self, $member, @args) = @_;
    my ($clusterset_id, $mlss) = rearrange([qw(CLUSTERSET_ID METHOD_LINK_SPECIES_SET)], @args);

    # Discard the UNIPROT members
    return if (ref($member) and not ($member->source_name =~ 'ENSEMBL'));

    my $member_id = (ref($member) ? $member->dbID : $member);
    my $constraint = '((m.member_id = ?) OR (m.gene_member_id = ?))';
    $self->bind_param_generic_fetch($member_id, SQL_INTEGER);
    $self->bind_param_generic_fetch($member_id, SQL_INTEGER);

    my $mlss_id = (ref($mlss) ? $mlss->dbID : $mlss);
    if (defined $mlss_id) {
        $constraint .= ' AND (tr.method_link_species_set_id = ?)';
        $self->bind_param_generic_fetch($mlss_id, SQL_INTEGER);
    }

    if (defined $clusterset_id) {
        $constraint .= ' AND (tr.clusterset_id = ?)';
        $self->bind_param_generic_fetch($clusterset_id, SQL_VARCHAR);
    }

    if (defined $self->_default_member_type) {
        $constraint .= ' AND (tr.member_type = ?)';
        $self->bind_param_generic_fetch($self->_default_member_type, SQL_VARCHAR);
    }

    my $join = [[['gene_tree_root', 'tr'], 't.root_id = tr.root_id']];
    return $self->generic_fetch($constraint, $join);
}


=head2 fetch_AlignedMember_by_member_id_root_id

  Description: DEPRECATED. Use fetch_all_AlignedMember_by_Member() instead

=cut

sub fetch_AlignedMember_by_member_id_root_id {
    my ($self, $member_id, $clusterset_id) = @_;
    deprecate('Use fetch_all_AlignedMember_by_Member($member_id, -clusterset_id=>$clusterset_id) instead');
    return $self->fetch_all_AlignedMember_by_Member($member_id, -clusterset_id => $clusterset_id)->[0];
}


=head2 fetch_AlignedMember_by_member_id_mlssID

  Description: DEPRECATED. Use fetch_all_AlignedMember_by_Member() instead

=cut

sub fetch_AlignedMember_by_member_id_mlssID {
    my ($self, $member_id, $mlss_id) = @_;
    deprecate('Use fetch_all_AlignedMember_by_Member($member_id, -method_link_species_set=>$mlss_id) instead');
    return $self->fetch_all_AlignedMember_by_Member($member_id, -method_link_species_set => $mlss_id)->[0];
}


=head2 gene_member_id_is_in_tree

  Description: DEPRECATED. Use fetch_all_by_Member($member_id) instead

=cut

sub gene_member_id_is_in_tree {
    my ($self, $member_id) = @_;
    deprecate('Use fetch_all_by_Member($member_id) instead');
    my $trees = $self->fetch_all_AlignedMember_by_Member($member_id);
    return $trees->[0]->root_id if $trees;
}


=head2 fetch_all_AlignedMember_by_root_id

  Arg[1]     : int: root_id: ID of the root node of the tree
  Example    : $all_members = $genetree_adaptor->fetch_all_AlignedMember_by_root_id($root_id);
  Description: Gets all the AlignedMembers of the given tree. This is equivalent to fetching
               the Member leaves of a tree, directly, without using the left/right_index
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_AlignedMember_by_root_id {
  my ($self, $root_id) = @_;

  my $constraint = '(tm.member_id IS NOT NULL) AND (t.root_id = ?)';
  $self->bind_param_generic_fetch($root_id, SQL_INTEGER);
  return $self->generic_fetch($constraint);

}

###########################
# stable_id mapping
###########################


=head2 fetch_by_stable_id

  Description: DEPRECATED. Use GeneTreeAdaptor::fetch_by_stable_id instead.

=cut

sub fetch_by_stable_id {
    my $self = shift;
    deprecate('Use Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor::fetch_by_stable_id instead');
    my $tree = $self->db->get_GeneTreeAdaptor->fetch_by_stable_id(@_);
    return $tree->root if (not defined $self->_default_member_type) or ($tree->member_type eq $self->_default_member_type);
}




###########################
# STORE methods
###########################

sub store {
    my ($self, $node) = @_;

    my $children = $node->children;
    # Firstly, store the node
    $self->store_node($node);

    # Secondly, recursively do all the children
    foreach my $child_node (@$children) {
        # Store the GeneTreeNode or the new GeneTree if different
        if ((not defined $child_node->tree) or ($child_node->root eq $node->root)) {
            $self->store($child_node);
        } else {
            $self->db->get_GeneTreeAdaptor->store($child_node->tree);
        }
    }

    return $node->node_id;

}

sub store_node {
    my ($self, $node) = @_;

    unless($node->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::GeneTreeNode] not a $node");
    }

    my $new_node = 0;
    if (not($node->adaptor and $node->adaptor->isa('Bio::EnsEMBL::Compara::DBSQL::GeneTreeNodeAdaptor') and $node->adaptor eq $self)) {
        my $sth = $self->prepare("INSERT INTO gene_tree_node VALUES ()");
        $sth->execute();
        $node->node_id( $sth->{'mysql_insertid'} );
        $new_node = 1;
    }

    my $parent_id = undef;
    $parent_id = $node->parent->node_id if($node->parent);

    my $root_id = $node->root->node_id;
    #print "inserting new_noe=$new_node parent_id=$parent_id, root_id=$root_id\n";

    my $sth = $self->prepare("UPDATE gene_tree_node SET parent_id=?, root_id=?, left_index=?, right_index=?, distance_to_parent=?  WHERE node_id=?");
    #print "UPDATE gene_tree_node  (", $parent_id, ",", $root_id, ",", $node->left_index, ",", $node->right_index, ",", $node->distance_to_parent, ") for ", $node->node_id, "\n";
    $sth->execute($parent_id, $root_id, $node->left_index, $node->right_index, $node->distance_to_parent, $node->node_id);
    $sth->finish;

    $node->adaptor($self);

    if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
        if ($new_node) {
            $sth = $self->prepare("INSERT INTO gene_tree_member (node_id, member_id, cigar_line)  VALUES (?,?,?)");
            $sth->execute($node->node_id, $node->member_id, $node->cigar_line);
            $sth->finish;
        } else {
            $sth = $self->prepare('UPDATE gene_tree_member SET cigar_line=? WHERE node_id = ?');
            $sth->execute($node->cigar_line, $node->node_id);
            $sth->finish;
        }
    }
    
    return $node->node_id;
}


sub merge_nodes {
  my ($self, $node1, $node2) = @_;

  unless($node1->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::GeneTreeNode] not a $node1");
  }

  # printf("MERGE children from parent %d => %d\n", $node2->node_id, $node1->node_id);

  my $sth = $self->prepare("UPDATE gene_tree_node SET parent_id=? WHERE parent_id=?");
  $sth->execute($node1->node_id, $node2->node_id);
  $sth->finish;

  $sth = $self->prepare("DELETE from gene_tree_node WHERE node_id=?");
  $sth->execute($node2->node_id);
  $sth->finish;
}

sub delete_flattened_leaf {
  my $self = shift;
  my $node = shift;

  my $node_id = $node->node_id;
  $self->dbc->do("DELETE from gene_tree_node_tag    WHERE node_id = $node_id");
  $self->dbc->do("DELETE from gene_tree_node_attr   WHERE node_id = $node_id");
  $self->dbc->do("DELETE from gene_tree_member WHERE node_id = $node_id");
  $self->dbc->do("DELETE from gene_tree_node   WHERE node_id = $node_id");
}

sub delete_node {
  my $self = shift;
  my $node = shift;

  my $node_id = $node->node_id;
  #print("delete node $node_id\n");
  $self->dbc->do("UPDATE gene_tree_node dn, gene_tree_node n SET ".
            "n.parent_id = dn.parent_id WHERE n.parent_id=dn.node_id AND dn.node_id=$node_id");
  $self->dbc->do("DELETE from gene_tree_node_tag    WHERE node_id = $node_id");
  $self->dbc->do("DELETE from gene_tree_node_attr   WHERE node_id = $node_id");
  $self->dbc->do("DELETE from gene_tree_member WHERE node_id = $node_id");
  $self->dbc->do("DELETE from gene_tree_node   WHERE node_id = $node_id");
}

sub delete_nodes_not_in_tree
{
  my $self = shift;
  my $tree = shift;

  unless($tree->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::GeneTreeNode] not a $tree");
  }
  #print("delete_nodes_not_present under ", $tree->node_id, "\n");
  my $dbtree = $self->fetch_node_by_node_id($tree->node_id);
  my @all_db_nodes = $dbtree->get_all_subnodes;
  foreach my $dbnode (@all_db_nodes) {
    next if($tree->find_node_by_node_id($dbnode->node_id));
    #print "Deleting unused node ", $dbnode->node_id, "\n";
    $self->delete_node($dbnode);
  }
  $dbtree->release_tree;
}


###################################
#
# tagging
#
###################################

sub _tag_capabilities {
    return ('gene_tree_node_tag', 'gene_tree_node_attr', 'node_id', 'node_id');
}


##################################
#
# subclass override methods
#
##################################

sub _columns {
  return ('t.node_id',
          't.parent_id',
          't.root_id',
          't.left_index',
          't.right_index',
          't.distance_to_parent',

          'tm.cigar_line',

          Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor->_columns()
          );
}

sub _tables {
  return (['gene_tree_node', 't'], ['gene_tree_member', 'tm'], ['member', 'm']);
}

sub _left_join {
    return (
        ['gene_tree_member', 't.node_id = tm.node_id'],
        ['member', 'tm.member_id = m.member_id'],
    );
}

sub _get_starting_lr_index {
    return 1;
}


sub create_instance_from_rowhash {
  my $self = shift;
  my $rowhash = shift;

  my $node;
  if($rowhash->{'member_id'}) {
    $node = new Bio::EnsEMBL::Compara::GeneTreeMember;
  } else {
    $node = new Bio::EnsEMBL::Compara::GeneTreeNode;
  }

  $self->init_instance_from_rowhash($node, $rowhash);

    if ((defined $self->{'_ref_tree'}) and ($self->{'_ref_tree'}->root_id eq $rowhash->{root_id})) {
        # GeneTree was passed via _ref_tree
        #print STDERR "REUSING GeneTree for $node :", $self->{'_ref_tree'};
        $node->tree($self->{'_ref_tree'});
    } 

  return $node;
}


sub init_instance_from_rowhash {
    my $self = shift;
    my $node = shift;
    my $rowhash = shift;

    # SUPER is NestedSetAdaptor
    $self->SUPER::init_instance_from_rowhash($node, $rowhash);
    if ($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
        # here is a gene leaf
        Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor->init_instance_from_rowhash($node, $rowhash);

        $node->cigar_line($rowhash->{'cigar_line'});
    } else {
        # here is an internal node
    }
    # print("  create node : ", $node, " : "); $node->print_node;
    $node->adaptor($self);

    return $node;
}


# Used as convenience to map the GeneTree objects to GeneTreeNode
# This method is actually only used by deprecated methods
sub _extract_roots_from_trees {
    my $self = shift;
    my $treearray_ref = shift;
    my @nodearray = ();
    #print scalar(@$treearray_ref), " elements to convert\n";
    foreach my $tree (@{$treearray_ref}) {
        push @nodearray, $tree->root if (not defined $self->_default_member_type) or ($tree->member_type eq $self->_default_member_type);
    }
    return \@nodearray;
}


sub _default_member_type {
    return undef;
}



###############################################################################
#
# Dynamic redefinition of functions to reuse the link to the GeneTree object
#
###############################################################################

foreach my $func_name (qw(
        fetch_all_children_for_node fetch_parent_for_node fetch_all_leaves_indexed
        fetch_subtree_under_node fetch_subroot_by_left_right_index fetch_root_by_node
        fetch_first_shared_ancestor_indexed
    )) {
    my $full_name = "Bio::EnsEMBL::Compara::DBSQL::GeneTreeNodeAdaptor::$func_name";
    my $super_name = "SUPER::$func_name";
    *$full_name = sub {
        my $self = shift;
        $self->{'_ref_tree'} = $_[0]->{'_tree'};
        my $ret = $self->$super_name(@_);
        delete $self->{'_ref_tree'};
        return $ret;
    };
    #print "REDEFINE $func_name\n";
}



1;
