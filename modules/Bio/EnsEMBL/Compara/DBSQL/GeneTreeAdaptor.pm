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

Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor

=head1 DESCRIPTION

Generic adaptor for a tree, later derived as ProteinTreeAdaptor or NCTreeAdaptor

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor
  `- Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor

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

package Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor;

use strict;
no strict 'refs';

use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::GeneTreeNode;
use Bio::EnsEMBL::Compara::GeneTreeMember;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;

use base ('Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');

###########################
# FETCH methods
###########################

=head2 fetch_all

  Arg[1]     : [optional] int clusterset_id (def. 1)
  Example    : $all_trees = $proteintree_adaptor->fetch_all(1);

  Description: Fetches from the database all the protein trees
  Returntype : arrayref of Bio::EnsEMBL::Compara::GeneTreeNode
  Exceptions :
  Caller     :

=cut

sub fetch_all {
    my $self = shift;
    my $constraint = "WHERE (t.node_id = t.root_id) AND (tr.tree_type NOT LIKE '%clusterset') AND (tr.tree_type NOT LIKE '%supertree')";

    my $clusterset_id = shift;
    $constraint .= " AND (tr.clusterset_id = ${clusterset_id})" if defined $clusterset_id;
    return $self->_generic_fetch($constraint);
}


sub fetch_all_roots {
  my $self = shift;

  my $constraint = "WHERE (t.node_id = t.root_id) AND (tr.tree_type LIKE '%clusterset')";
  return $self->_generic_fetch($constraint);
}


=head2 fetch_by_Member_root_id

  Arg[1]     : Bio::EnsEMBL::Compara::Member
  Arg[2]     : [optional] int clusterset_id (def. 1)
  Example    : $protein_tree = $proteintree_adaptor->fetch_by_Member_root_id($member);

  Description: Fetches from the database the protein_tree that contains the
               member. If you give it a clusterset id of 0 this will cause
               the search span across all known clustersets.
  Returntype : Bio::EnsEMBL::Compara::GeneTreeNode
  Exceptions :
  Caller     :

=cut


sub fetch_by_Member_root_id {
  my ($self, $member, $clusterset_id) = @_;
  $clusterset_id = 1 if ! defined $clusterset_id;

  my $root_id = $self->gene_member_id_is_in_tree($member->gene_member_id || $member->member_id);

  return undef unless (defined $root_id);
  my $aligned_member = $self->fetch_AlignedMember_by_member_id_root_id
    (
    $self->_get_canonical_Member($member)->member_id,
     $clusterset_id);
  return undef unless (defined $aligned_member);
  my $node = $aligned_member->subroot;
  return undef unless (defined $node);
  my $gene_tree = $self->fetch_node_by_node_id($node->node_id);

  return $gene_tree;
}


=head2 fetch_by_gene_Member_root_id

=cut

sub fetch_by_gene_Member_root_id {
  my ($self, $member, $clusterset_id) = @_;
  $clusterset_id = 1 if ! defined $clusterset_id;

  my $root_id = $self->gene_member_id_is_in_tree($member->member_id);
  return undef unless (defined $root_id);
  my $gene_tree = $self->fetch_node_by_node_id($root_id);

  return $gene_tree;
}


=head2 fetch_AlignedMember_by_member_id_root_id

  Arg[1]     : int member_id of a peptide member (longest translation)
  Arg[2]     : [optional] int clusterset_id (def. 0)
  Example    :

      my $aligned_member = $proteintree_adaptor->
                            fetch_AlignedMember_by_member_id_root_id
                            (
                             $member->get_canonical_peptide_Member->member_id
                            );

  Description: Fetches from the database the protein_tree that contains the member_id
  Returntype : Bio::EnsEMBL::Compara::GeneTreeMember
  Exceptions :
  Caller     :

=cut

sub fetch_AlignedMember_by_member_id_root_id {
  my ($self, $member_id, $clusterset_id) = @_;

  my $constraint = "WHERE tm.member_id = $member_id and m.member_id = $member_id";
  $constraint .= " AND tr.clusterset_id = $clusterset_id" if($clusterset_id and $clusterset_id>0);
  my $final_clause = "order by tm.node_id desc";
  $self->final_clause($final_clause);
  my ($node) = @{$self->_generic_fetch($constraint)};
  return $node;
}

=head2 fetch_AlignedMember_by_member_id_mlssID

  Arg[1]     : int member_id of a peptide member (longest translation)
  Arg[2]     : [optional] int clusterset_id (def. 0)
  Example    :

      my $aligned_member = $proteintree_adaptor->
                            fetch_AlignedMember_by_member_id_mlssID
                            (
                             $member->get_canonical_peptide_Member->member_id, $mlssID
                            );

  Description: Fetches from the database the protein_tree that contains the member_id
  Returntype : Bio::EnsEMBL::Compara::GeneTreeMember
  Exceptions :
  Caller     :

=cut


sub fetch_AlignedMember_by_member_id_mlssID {
  my ($self, $member_id, $mlss_id) = @_;

  my $constraint = "WHERE tm.member_id = $member_id and m.member_id = $member_id";
  $constraint .= " AND tr.method_link_species_set_id = $mlss_id" if($mlss_id and $mlss_id>0);
  my ($node) = @{$self->_generic_fetch($constraint)};
  return $node;
}


sub gene_member_id_is_in_tree {
  my ($self, $member_id) = @_;

  my $sth = $self->prepare("SELECT gtn.root_id FROM member m, gene_tree_member gtm, gene_tree_node gtn WHERE gtm.member_id=m.member_id AND gtm.node_id=gtn.node_id AND m.gene_member_id=? LIMIT 1");
  $sth->execute($member_id);
  my($root_id) = $sth->fetchrow_array;

  if (defined($root_id)) {
    return $root_id;
  } else {
    return undef;
  }
}

sub fetch_all_AlignedMembers_by_root_id {
  my ($self, $root_id) = @_;

  my $constraint = "WHERE tm.root_id = $root_id";
  my $nodes = $self->_generic_fetch($constraint);
  return $nodes;

}

###########################
# stable_id mapping
###########################


=head2 fetch_by_stable_id

  Arg[1]     : string $protein_tree_stable_id
  Example    : $protein_tree = $proteintree_adaptor->fetch_by_stable_id("ENSGT00590000083078");

  Description: Fetches from the database the protein_tree for that stable ID
  Returntype : Bio::EnsEMBL::Compara::GeneTreeNode
  Exceptions : returns undef if $stable_id is not found.
  Caller     :

=cut

sub fetch_by_stable_id {
  my ($self, $stable_id) = @_;

  my $sql = "SELECT root_id FROM gene_tree_root WHERE stable_id=\"$stable_id\"";
  my $sth = $self->prepare($sql);
  $sth->execute();

  my ($root_id) = $sth->fetchrow_array();
  $sth->finish();

  return undef unless (defined $root_id);

  my $protein_tree = $self->fetch_node_by_node_id($root_id);

  return $protein_tree;
}




###########################
# STORE methods
###########################

sub store {
    my ($self, $object) = @_;
    #print "GeneTreeAdaptor::store($object)\n";

    if ($object->isa('Bio::EnsEMBL::Compara::GeneTree')) {

        # We have a GeneTree object
        return $self->store_tree($object);

    } elsif ($object->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {

        # We have a GeneTreeNode object
        my $node = $object;
        # Firstly, store the node
        $self->store_node($node);
        # Secondly, recursively do all the children
        my $children = $node->children;
        foreach my $child_node (@$children) {
            # Store the GeneTreeNode or the new GeneTree if different
            if ((not defined $child_node->tree) or ($child_node->root eq $node->root)) {
                $self->store($child_node);
            } else {
                $self->store_tree($child_node->tree);
            }
        }

        return $node->node_id;

    } else {
        throw("arg must be a [Bio::EnsEMBL::Compara::GeneTreeNode] or a [Bio::EnsEMBL::Compara::GeneTree], but not a $object");
    }
}

sub store_tree {
    my ($self, $tree) = @_;

    # Firstly, store the nodes
    my $root_id = $self->store($tree->root);

    # Secondly, the tree itself
    if ($tree->adaptor and $tree->adaptor->isa('Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor') and $tree->adaptor eq $self) {
        # Update 
        my $sth = $self->prepare("UPDATE gene_tree_root SET tree_type = ?, clusterset_id = ?, method_link_species_set_id = ?, stable_id = ?, version = ? WHERE root_id = ?");
        #print "UPDATE INTO gene_tree_root (", $root_id, " ", $tree->tree_type, " ", $tree->clusterset_id, " ", $tree->method_link_species_set_id, " ", $tree->stable_id, " ", $tree->version, "\n";
        $sth->execute($tree->tree_type, $tree->clusterset_id, $tree->method_link_species_set_id, $tree->stable_id, $tree->version, $root_id);
        $sth->finish;
    } else {
        # Insert
        $tree->adaptor($self);
        my $sth = $self->prepare("INSERT INTO gene_tree_root (root_id, tree_type, clusterset_id, method_link_species_set_id, stable_id, version) VALUES (?,?,?,?,?,?)");
        #print "INSERT INTRO gene_tree_root (", $root_id, " ", $tree->tree_type, " ", $tree->clusterset_id, " ", $tree->method_link_species_set_id, " ", $tree->stable_id, " ", $tree->version, "\n";
        $sth->execute($root_id, $tree->tree_type, $tree->clusterset_id, $tree->method_link_species_set_id, $tree->stable_id, $tree->version);
        $sth->finish;
    }

    return $root_id;
}

sub store_node {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::GeneTreeNode] not a $node");
  }

  if($node->adaptor and
     $node->adaptor->isa('Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor') and
     $node->adaptor eq $self)
  {
    #already stored so just update
    return $self->update_node($node);
  }

  my $parent_id = undef; my $root_id = undef;
  if($node->parent) {
    $parent_id = $node->parent->node_id;
  }

  if (($node ne $node->root) or not $node->node_id->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
    $root_id = $node->root->node_id;
  }
  #print "inserting parent_id=$parent_id, root_id=$root_id\n";

  my $sth = $self->prepare("INSERT INTO gene_tree_node (parent_id, root_id, left_index, right_index, distance_to_parent)  VALUES (?,?,?,?,?)");
  #print "INSERT INTO gene_tree_node (", $parent_id, " ", $root_id, " ", $node->left_index, " ", $node->right_index, " ", $node->distance_to_parent, "\n";
  $sth->execute($parent_id, $root_id, $node->left_index, $node->right_index, $node->distance_to_parent);

  $node->node_id( $sth->{'mysql_insertid'} );
  #printf("  new node_id %d\n", $node->node_id);
  $node->adaptor($self) if not defined $node->adaptor;
  $sth->finish;

  if(not defined $root_id) {
    $sth = $self->prepare("UPDATE gene_tree_node SET root_id=node_id WHERE node_id=?");
    #print "UPDATE gene_tree_node SET root_id=node_id WHERE node_id=", $node->node_id, "\n";
    $sth->execute($node->node_id);
    $sth->finish;
  }


  if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
    $sth = $self->prepare("INSERT IGNORE INTO gene_tree_member (node_id, member_id, cigar_line)  VALUES (?,?,?)");
    #print "INSERT IGNORE INTO gene_tree_member (", $node->node_id, " ", $node->member_id, " ", $node->cigar_line, "\n";
    $sth->execute($node->node_id, $node->member_id, $node->cigar_line);
    $sth->finish;
  }
  return $node->node_id;
}

sub update_node {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::GeneTreeNode] not a $node");
  }
  #print "UPDATING $node ";
  my $parent_id = undef; my $root_id = undef;
  if($node->parent) {
    $parent_id = $node->parent->node_id;
  }
    $root_id = $node->root->node_id;

  my $sth = $self->prepare("UPDATE gene_tree_node SET parent_id=?, root_id=?, left_index=?, right_index=?, distance_to_parent=?  WHERE node_id=?");
  #print "UPDATE gene_tree_node  (", $parent_id, ",", $root_id, ",", $node->left_index, ",", $node->right_index, ",", $node->distance_to_parent, ") for ", $node->node_id, "\n";

  $sth->execute($parent_id, $root_id, $node->left_index, $node->right_index,
                $node->distance_to_parent, $node->node_id);

  $node->adaptor($self);
  $sth->finish;

  if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
    my $sql = "UPDATE gene_tree_member SET ".
              "cigar_line='". $node->cigar_line . "'";
    $sql .= ", cigar_start=" . $node->cigar_start if($node->cigar_start);
    $sql .= ", cigar_end=" . $node->cigar_end if($node->cigar_end);
    $sql .= " WHERE node_id=". $node->node_id;
    #print $sql, "\n";
    $self->dbc->do($sql);
  }

}


sub merge_nodes {
  my ($self, $node1, $node2) = @_;

  unless($node1->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::GeneTreeNode] not a $node1");
  }

  # printf("MERGE children from parent %d => %d\n", $node2->node_id, $node1->node_id);

  my $sth = $self->prepare("UPDATE gene_tree_node SET
                              parent_id=?
			      WHERE parent_id=?");
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
    my $self = shift;
    my $object = shift;
    #print "CAPABILITIES $object ";
    if ($object->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
        #print " = NODE\n";
        return ("gene_tree_node_tag", "gene_tree_node_attr", "node_id", "node_id");
    } elsif ($object->isa('Bio::EnsEMBL::Compara::GeneTree')) {
        #print " = ROOT\n";
        return ("gene_tree_root_tag", undef, "root_id", "root_id");
    } else {
        die "$self cannot handle tags/attributes for $object\n";
    }
}


##################################
#
# subclass override methods
#
##################################

sub columns {
  my $self = shift;
  return ['t.node_id',
          't.parent_id',
          't.root_id',
          't.left_index',
          't.right_index',
          't.distance_to_parent',

          'tr.stable_id',
          'tr.tree_type',
          'tr.version',
          'tr.clusterset_id',
          'tr.method_link_species_set_id',

          'tm.cigar_line',
          'tm.cigar_start',
          'tm.cigar_end',

          @{Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor->columns()}
          ];
}

sub tables {
  my $self = shift;
  return [['gene_tree_node', 't']];
}

sub left_join_clause {
    my $self = shift;
    return "LEFT JOIN gene_tree_member tm ON t.node_id = tm.node_id LEFT JOIN member m ON tm.member_id = m.member_id LEFT JOIN gene_tree_root tr ON t.root_id = tr.root_id";
}

sub default_where_clause {
    return "";
}

sub _get_starting_lr_index {
  return 1;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  my $node_list = [];

  while(my $rowhash = $sth->fetchrow_hashref) {
    my $node = $self->create_instance_from_rowhash($rowhash);
    push @$node_list, $node;
  }

  return $node_list;
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
  $self->_add_GeneTree_wrapper($node, $rowhash);
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


sub _add_GeneTree_wrapper {
    my $self = shift;
    my $node = shift;
    my $rowhash = shift;

    if ((defined $self->{'_ref_tree'}) and ($self->{'_ref_tree'}->root_id eq $rowhash->{root_id})) {
        # GeneTree was passed via _ref_tree
        #print STDERR "REUSING GeneTree for $node :", $self->{'_ref_tree'};
        $node->tree($self->{'_ref_tree'});

    } else {

        # Must create a new GeneTree
        my $tree = new Bio::EnsEMBL::Compara::GeneTree;

        # Common Fields
        foreach my $attr (qw(tree_type method_link_species_set_id clusterset_id stable_id version)) {
            $tree->$attr($rowhash->{$attr});
        }
        $tree->adaptor($self);
        $node->tree($tree);
       
        # Lazy initialisation: only one of root() and root_id() is needed
        if ($node->node_id == $rowhash->{root_id}) {
            # The node is the tree root
            $tree->root($node);
        } else {
            $tree->root_id($rowhash->{root_id})
        }
        #print STDERR "NEW GeneTree for $node :", Dumper($tree);
    }
}



##########################################################
#
# explicit method forwarding to MemberAdaptor
#
##########################################################

sub _fetch_sequence_by_id {
  my $self = shift;
  return $self->db->get_MemberAdaptor->_fetch_sequence_by_id(@_);
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
    my $full_name = "Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor::$func_name";
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
