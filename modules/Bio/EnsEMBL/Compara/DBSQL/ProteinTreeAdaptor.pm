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
use Switch;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;
our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor);


###########################
# FETCH methods
###########################

sub fetch_AlignedMember_by_member_id_root_id {
  my ($self, $member_id, $root_id) = @_;
    
  my $constraint = "WHERE tm.member_id = $member_id and m.member_id = $member_id and t.root_id = $root_id";
  my ($node) = @{$self->_generic_fetch($constraint)};
  return $node;
}



###########################
# STORE methods
###########################

sub update {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }
  
  my $parent_id = 0;
  my $root_id = 0;
  if($node->parent) {
    $parent_id = $node->parent->node_id ;
    $root_id = $node->root->node_id;
  }

  my $sth = $self->prepare("UPDATE protein_tree_nodes SET
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
    $sql .= " cigar_start=" . $node->cigar_start if($node->cigar_start);              
    $sql .= " cigar_end=" . $node->cigar_end if($node->cigar_end);              
    $sql .= " WHERE node_id=". $node->node_id;
    $self->dbc->do($sql);
  }

}


=head2 store

  Arg [1]    :
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub store {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }
  
  if($node->adaptor and 
     $node->adaptor->isa('Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor') and
     $node->adaptor eq $self) 
  {
    #already stored so just update
    return $self->update($node);
  }
  
  my $parent_id = 0;
  my $root_id = 0;
  if($node->parent) {
    $parent_id = $node->parent->node_id ;
    $root_id = $node->root->node_id;
  }

  my $sth = $self->prepare("INSERT INTO protein_tree_nodes 
                             (parent_id,
                              root_id,
                              left_index,
                              right_index,
                              distance_to_parent)  VALUES (?,?,?,?,?)");
  $sth->execute($parent_id, $root_id, $node->left_index, $node->right_index, $node->distance_to_parent);

  $node->node_id( $sth->{'mysql_insertid'} );
  $node->adaptor($self);
  $sth->finish;

  if($node->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
    $sth = $self->prepare("INSERT ignore INTO protein_tree_member 
                               (node_id,
                                member_id,
                                cigar_line)  VALUES (?,?,?)");
    $sth->execute($node->node_id, $node->member_id, $node->cigar_line);
    $sth->finish;
  }


  #
  #now recursively do all the children
  #
  my $children = $node->children;
  foreach my $child_node (@$children) {  
    $self->store($child_node);
  }

  return $node->node_id;
}


sub merge_nodes {
  my ($self, $node1, $node2) = @_;

  unless($node1->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node1");
  }
  
  # printf("MERGE children from parent %d => %d\n", $node2->node_id, $node1->node_id);
  
  my $sth = $self->prepare("UPDATE protein_tree_nodes SET
                              parent_id=?,
                              root_id=?
			                     WHERE parent_id=?");
  $sth->execute($node1->node_id, $node1->root->node_id, $node2->node_id);
  $sth->finish;
  
  $sth = $self->prepare("DELETE from protein_tree_nodes WHERE node_id=?");
  $sth->execute($node2->node_id);
  $sth->finish;
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
          
          'tm.cigar_line',
          'tm.cigar_start',
          'tm.cigar_end',

          @{Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor->columns()}
          ];
}

sub tables {
  my $self = shift;
  return [['protein_tree_nodes', 't']];
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
    $node = new Bio::EnsEMBL::Compara::NestedSet;
  }
  
  $self->init_instance_from_rowhash($node, $rowhash);
  return $node;
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
    $node->cigar_start($rowhash->{'cigar_start'});
    $node->cigar_end($rowhash->{'cigar_end'});
  }
  # print("  create node : ", $node, " : "); $node->print_node;

  $node->adaptor($self);
  
  return $node;
}


sub parse_newick_into_tree
{
  my $self = shift;
  my $newick = shift;
  my $tree = shift;
  
  $newick = "(Mouse:0.76985,
              ((((Human:0.11449,Chimp:0.15471):0.03695,
                 Gorilla:0.15680):0.02121,
                   Orang:0.29209)Hominidae:0.04986,
                   Gibbon:0.35537)Hominoidea:0.41983,
                   Bovine:0.91675);";

  my $count=1;
  my $root = new Bio::EnsEMBL::Compara::NestedSet;
  $root->node_id($count++);
  
  my $state=1;
  $newick =~ s/\s//g;
  print("$newick\n");
  my $token = next_token(\$newick, "(");
  my $lastset = $root;
  my $node = $root;

  while($token) {
    printf("state %d : '%s'\n", $state, $token);
    switch ($state) {
      case 1 { #new node
        $node = new Bio::EnsEMBL::Compara::NestedSet;
        $node->node_id($count++);
        $lastset->add_child($node);
        if($token eq '(') { #create new set
          #printf("    create set\n");
          $token = next_token(\$newick, "(:,");
          $state = 1;
          $lastset = $node;
        } else {
          $state = 2;
        }
      }
      case 2 { #naming a node
        if(!($token =~ /[:,);]/)) { 
          $node->name($token);
          print("    naming leaf"); $node->print_node;
          $token = next_token(\$newick, ":,)");
        }
        $state = 3;
      }
      case 3 { # optional : and distance
        if($token eq ':') {
          $token = next_token(\$newick, ",)");
          $node->distance_to_parent($token);
          print("set distance: $token"); $node->print_node;
          $token = next_token(\$newick, ",)"); #move to , or )
        }
        $state = 4;
      }
      case 4 { # end node
        if($token eq ')') {
          print("end set : "); $lastset->print_node;
          $node = $lastset;        
          $lastset = $lastset->parent;
          $token = next_token(\$newick, ":,);");
          $state=2;
        } elsif($token eq ',') {
          $token = next_token(\$newick, "(:,");
          $state=1;
        } elsif($token eq ';') {
          #done with tree
          $state=1;
          $token = next_token(\$newick, "(");
        } else {
          throw("parse error: expected ')' or ','\n");
        }
      }

    }
  }
  
  $root->print_tree;
  $root->release;
}

sub next_token {
  my $string = shift;
  my $delim = shift;
  
  return undef unless(length($$string));
  
  #print("input =>$$string\n");
  #print("delim =>$delim\n");
  my $index=undef;

  my @delims = split(/ */, $delim);
  foreach my $dl (@delims) {
    my $pos = index($$string, $dl);
    if($pos>=0) {
      $index = $pos unless(defined($index));
      $index = $pos if($pos<$index);
    }
  }
  unless(defined($index)) {
    throw("couldn't find delimiter $delim\n");
  }

  my $token ='';

  if($index==0) {
    $token = substr($$string,0,1);
    $$string = substr($$string, 1);
  } else {
    $token = substr($$string, 0, $index);
    $$string = substr($$string, $index);
  }

  #print("  token     =>$token\n");
  #print("  outstring =>$$string\n\n");
  
  return $token;
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
