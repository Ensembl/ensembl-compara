=head1 NAME

ProteinTreeAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::ProteinTreeAdaptor;

use strict;
use Bio::EnsEMBL::Compara::ProteinTree;
use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;
our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor);

###########################
# FETCH methods
###########################

=head2 fetch_by_Member_root_id

  Arg[1]     : Bio::EnsEMBL::Compara::Member
  Arg[2]     : [optional] int clusterset_id (def. 1)
  Example    : $protein_tree = $proteintree_adaptor->fetch_by_Member_root_id($member);

  Description: Fetches from the database the protein_tree that contains the member
  Returntype : Bio::EnsEMBL::Compara::ProteinTree
  Exceptions :
  Caller     :

=cut


sub fetch_by_Member_root_id {
  my ($self, $member, $root_id) = @_;
  $root_id = $root_id || 1;

  my $aligned_member = $self->fetch_AlignedMember_by_member_id_root_id
    (
     $member->get_longest_peptide_Member->member_id,
     $root_id);
  return undef unless (defined $aligned_member);
  my $node = $aligned_member->subroot;
  return undef unless (defined $node);
  my $protein_tree = $self->fetch_node_by_node_id($node->node_id);

  return $protein_tree;
}


=head2 fetch_AlignedMember_by_member_id_root_id

  Arg[1]     : int member_id of a peptide member (longest translation)
  Arg[2]     : [optional] int clusterset_id (def. 0)
  Example    :

      my $aligned_member = $proteintree_adaptor->
                            fetch_AlignedMember_by_member_id_root_id
                            (
                             $member->get_longest_peptide_Member->member_id
                            );

  Description: Fetches from the database the protein_tree that contains the member_id
  Returntype : Bio::EnsEMBL::Compara::AlignedMember
  Exceptions :
  Caller     :

=cut


sub fetch_AlignedMember_by_member_id_root_id {
  my ($self, $member_id, $clusterset_id) = @_;

  my $constraint = "WHERE tm.member_id = $member_id and m.member_id = $member_id";
  $constraint .= " AND t.clusterset_id = $clusterset_id" if($clusterset_id and $clusterset_id>0);
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
                             $member->get_longest_peptide_Member->member_id, $mlssID
                            );

  Description: Fetches from the database the protein_tree that contains the member_id
  Returntype : Bio::EnsEMBL::Compara::AlignedMember
  Exceptions :
  Caller     :

=cut


sub fetch_AlignedMember_by_member_id_mlssID {
  my ($self, $member_id, $mlss_id) = @_;

  my $constraint = "WHERE tm.member_id = $member_id and m.member_id = $member_id";
  $constraint .= " AND tm.method_link_species_set_id = $mlss_id" if($mlss_id and $mlss_id>0);
  my ($node) = @{$self->_generic_fetch($constraint)};
  return $node;
}


###########################
# STORE methods
###########################


sub store {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  $self->store_node($node);

  # recursively do all the children
  my $children = $node->children;
  foreach my $child_node (@$children) {
    $child_node->clusterset_id($node->clusterset_id) unless (defined($child_node->clusterset_id));
    $self->store($child_node);
  }

  return $node->node_id;
}

sub delete_tag {
  my $self = shift;
  my $node_id = shift;
  my $tag = shift;

  my $sql = "DELETE from protein_tree_tag where node_id=$node_id and tag=\"$tag\"";
  #print("$sql\n");
  $self->dbc->do($sql);
}

sub store_node {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  if($node->adaptor and 
     $node->adaptor->isa('Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor') and
     $node->adaptor eq $self) 
  {
    #already stored so just update
    return $self->update_node($node);
  }

  my $parent_id = 0; my $root_id = 0; my $clusterset_id = undef;
  if($node->parent) {
    $parent_id = $node->parent->node_id;
    if (ref($node->node_id)) {
      # We got here because we haven't stored this node and so it
      # doesn't have a node_id, returning a hashref (node object) for node_id
      # instead of an integer
      $root_id = $node->root->node_id;
    } else {
      $root_id = $node->subroot->node_id;
    }
  }
  $clusterset_id = $node->clusterset_id || 1;
  #printf("inserting parent_id = %d, root_id = %d\n", $parent_id, $root_id);

  my $sth = $self->prepare("INSERT INTO protein_tree_node 
                             (parent_id,
                              root_id,
                              clusterset_id,
                              left_index,
                              right_index,
                              distance_to_parent)  VALUES (?,?,?,?,?,?)");
  $sth->execute($parent_id, $root_id, $clusterset_id, $node->left_index, $node->right_index, $node->distance_to_parent);

  $node->node_id( $sth->{'mysql_insertid'} );
  #printf("  new node_id %d\n", $node->node_id);
  $node->adaptor($self);
  $sth->finish;

  if($node->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
    $sth = $self->prepare("INSERT ignore INTO protein_tree_member 
                               (node_id,
                                root_id,
                                member_id,
                                method_link_species_set_id,
                                cigar_line)  VALUES (?,?,?,?,?)");
    $sth->execute($node->node_id, $root_id, $node->member_id, $node->method_link_species_set_id, $node->cigar_line);
    $sth->finish;
  }

  return $node->node_id;
}


sub update_node {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  my $parent_id = 0; my $root_id = 0; my $clusterset_id = undef;
  if($node->parent) {
    $parent_id = $node->parent->node_id;
    if (ref($node->node_id)) {
      # We got here because we haven't stored this node and so it
      # doesn't have a node_id, returning a hashref (node object) for node_id
      # instead of an integer
      $root_id = $node->root->node_id;
    } else {
      $root_id = $node->subroot->node_id;
    }
    $clusterset_id = $node->clusterset_id || 1;
  }

  my $sth = $self->prepare("UPDATE protein_tree_node SET
                            parent_id=?,
                            root_id=?,
                            left_index=?,
                            right_index=?,
                            distance_to_parent=? 
                            WHERE node_id=?");
  $sth->execute($parent_id, $root_id, $node->left_index, $node->right_index, 
                $node->distance_to_parent, $node->node_id);

  $node->adaptor($self);
  $sth->finish;

  if($node->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
    my $sql = "UPDATE protein_tree_member SET ". 
              "cigar_line='". $node->cigar_line . "'";
    $sql .= ", cigar_start=" . $node->cigar_start if($node->cigar_start);
    $sql .= ", cigar_end=" . $node->cigar_end if($node->cigar_end);
    $sql .= ", root_id=" . $root_id;
    $sql .= ", method_link_species_set_id=" . $node->method_link_species_set_id if($node->method_link_species_set_id);
    $sql .= " WHERE node_id=". $node->node_id;
    $self->dbc->do($sql);
  }

}


sub merge_nodes {
  my ($self, $node1, $node2) = @_;

  unless($node1->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node1");
  }

  # printf("MERGE children from parent %d => %d\n", $node2->node_id, $node1->node_id);

  my $sth = $self->prepare("UPDATE protein_tree_node SET
                              parent_id=?
			      WHERE parent_id=?");
  $sth->execute($node1->node_id, $node2->node_id);
  $sth->finish;

  $sth = $self->prepare("DELETE from protein_tree_node WHERE node_id=?");
  $sth->execute($node2->node_id);
  $sth->finish;
}

sub delete_flattened_leaf {
  my $self = shift;
  my $node = shift;

  my $node_id = $node->node_id;
  #print("delete node $node_id\n");
#   $self->dbc->do("UPDATE protein_tree_node dn, protein_tree_node n SET ". 
#             "n.parent_id = dn.parent_id WHERE n.parent_id=dn.node_id AND dn.node_id=$node_id");
  $self->dbc->do("DELETE from protein_tree_node WHERE node_id = $node_id");
  $self->dbc->do("DELETE from protein_tree_tag WHERE node_id = $node_id");
  $self->dbc->do("DELETE from protein_tree_member WHERE node_id = $node_id");
}

sub delete_node {
  my $self = shift;
  my $node = shift;

  my $node_id = $node->node_id;
  #print("delete node $node_id\n");
  $self->dbc->do("UPDATE protein_tree_node dn, protein_tree_node n SET ". 
            "n.parent_id = dn.parent_id WHERE n.parent_id=dn.node_id AND dn.node_id=$node_id");
  $self->dbc->do("DELETE from protein_tree_node WHERE node_id = $node_id");
  $self->dbc->do("DELETE from protein_tree_tag WHERE node_id = $node_id");
  $self->dbc->do("DELETE from protein_tree_member WHERE node_id = $node_id");
}


sub delete_nodes_not_in_tree
{
  my $self = shift;
  my $tree = shift;

  unless($tree->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $tree");
  }
  #print("delete_nodes_not_present under ", $tree->node_id, "\n");
  my $dbtree = $self->fetch_node_by_node_id($tree->node_id);
  my @all_db_nodes = $dbtree->get_all_subnodes;
  foreach my $dbnode (@all_db_nodes) {
    next if($tree->find_node_by_node_id($dbnode->node_id));
    $self->delete_node($dbnode);
  }
  $dbtree->release_tree;
}

sub delete_node_and_under {
  my $self = shift;
  my $node = shift;

  my @all_subnodes = $node->get_all_subnodes;
  foreach my $subnode (@all_subnodes) {
    my $subnode_id = $subnode->node_id;
    $self->dbc->do("DELETE from protein_tree_node WHERE node_id = $subnode_id");
    $self->dbc->do("DELETE from protein_tree_tag WHERE node_id = $subnode_id");
    $self->dbc->do("DELETE from protein_tree_member WHERE node_id = $subnode_id");
  }
  my $node_id = $node->node_id;
  $self->dbc->do("DELETE from protein_tree_node WHERE node_id = $node_id");
  $self->dbc->do("DELETE from protein_tree_tag WHERE node_id = $node_id");
  $self->dbc->do("DELETE from protein_tree_member WHERE node_id = $node_id");
}

sub store_supertree_node_and_under {
  my $self = shift;
  my $node = shift;
  $DB::single=1;1;
  $self->dbc->do("CREATE TABLE IF NOT EXISTS super_protein_tree_node like protein_tree_node");
  $self->dbc->do("CREATE TABLE IF NOT EXISTS super_protein_tree_member like protein_tree_member");
  $self->dbc->do("CREATE TABLE IF NOT EXISTS super_protein_tree_tag like protein_tree_tag");

  my @all_subnodes = $node->get_all_subnodes;
  foreach my $subnode (@all_subnodes) {
    my $subnode_id = $subnode->node_id;
    $self->dbc->do("INSERT IGNORE into super_protein_tree_node SELECT * from protein_tree_node WHERE node_id = $subnode_id");
    $self->dbc->do("INSERT IGNORE into super_protein_tree_member SELECT * from protein_tree_member WHERE node_id = $subnode_id");
    $self->dbc->do("INSERT IGNORE into super_protein_tree_tag SELECT * from protein_tree_tag WHERE node_id = $subnode_id");
  }
  my $node_id = $node->node_id;
  $self->dbc->do("INSERT IGNORE into super_protein_tree_node SELECT * from protein_tree_node WHERE node_id = $node_id");
  $self->dbc->do("INSERT IGNORE into super_protein_tree_member SELECT * from protein_tree_member WHERE node_id = $node_id");
  $self->dbc->do("INSERT IGNORE into super_protein_tree_tag SELECT * from protein_tree_tag WHERE node_id = $node_id");
}

###################################
#
# tagging 
#
###################################

sub _load_tagvalues {
  my $self = shift;
  my $node = shift;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  my $sth = $self->prepare("SELECT tag,value from protein_tree_tag where node_id=?");
  $sth->execute($node->node_id);  
  while (my ($tag, $value) = $sth->fetchrow_array()) {
    $node->add_tag($tag,$value);
  }
  $sth->finish;
}


sub _store_tagvalue {
  my $self = shift;
  my $node_id = shift;
  my $tag = shift;
  my $value = shift;

  $value="" unless(defined($value));

  my $sql = "INSERT ignore into protein_tree_tag (node_id,tag) values ($node_id,\"$tag\")";
  #print("$sql\n");
  $self->dbc->do($sql);

  $sql = "UPDATE protein_tree_tag set value=\"$value\" where node_id=$node_id and tag=\"$tag\"";
  #print("$sql\n");
  $self->dbc->do($sql);
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
          't.clusterset_id',
          't.left_index',
          't.right_index',
          't.distance_to_parent',

          'tm.cigar_line',
          'tm.cigar_start',
          'tm.cigar_end',

          @{Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor->columns()}
          ];
}

sub tables {
  my $self = shift;
  return [['protein_tree_node', 't']];
}

sub left_join_clause {
  return "left join protein_tree_member tm on t.node_id = tm.node_id left join member m on tm.member_id = m.member_id";
}

sub default_where_clause {
  return "";
}


sub create_instance_from_rowhash {
  my $self = shift;
  my $rowhash = shift;

  my $node;
  if($rowhash->{'member_id'}) {
    $node = new Bio::EnsEMBL::Compara::AlignedMember;
  } else {
    $node = new Bio::EnsEMBL::Compara::ProteinTree;
  }

  $self->init_instance_from_rowhash($node, $rowhash);
  return $node;
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


sub init_instance_from_rowhash {
  my $self = shift;
  my $node = shift;
  my $rowhash = shift;

  #SUPER is NestedSetAdaptor
  $self->SUPER::init_instance_from_rowhash($node, $rowhash);
   if($rowhash->{'member_id'}) {
    Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor->init_instance_from_rowhash($node, $rowhash);

    $node->cigar_line($rowhash->{'cigar_line'});
# cigar_start and cigar_end does not need to be set.
#    $node->cigar_start($rowhash->{'cigar_start'});
#    $node->cigar_end($rowhash->{'cigar_end'});
  }
  # print("  create node : ", $node, " : "); $node->print_node;

  $node->adaptor($self);

  return $node;
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

sub fetch_gene_for_peptide_member_id { 
  my $self = shift;
  return $self->db->get_MemberAdaptor->fetch_gene_for_peptide_member_id(@_);
}

sub fetch_peptides_for_gene_member_id {
  my $self = shift;
  return $self->db->get_MemberAdaptor->fetch_peptides_for_gene_member_id(@_);
}

sub fetch_longest_peptide_member_for_gene_member_id {
  my $self = shift;
  return $self->db->get_MemberAdaptor->fetch_longest_peptide_member_for_gene_member_id(@_);
}

1;
