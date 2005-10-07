#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Graph::ConnectedComponents

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('PAFCluster');
my $rdb = new Bio::EnsEMBL::Compara::Graph::ConnectedComponents(
                         -input_id   => "{'species_set'=>[1,2,3,14]}",
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a general purpose tool for building connected component clusters
from pairs of scalars.  The scalars can be any perl scalar (number, string, 
object reference, hash reference, list reference) The scalars are treated as
distinct IDs so that equal scalars point to the same node/component.
As new scalar IDs are encountered new nodes are created and clusters are grown
and merged as the connections are added.  It uses the NestedSet data structure.
typical use would be
    my $ccEngine = new Bio::EnsEMBL::Compara::Graph::ConnectedComponents;
    foreach my($node_id1, $node_id2) (@some_list_of_pairs) {
      $ccEngine->add_connection($node_id1, $node_id2);
    }
    printf("built %d clusters\n", $ccEngine->get_cluster_count);
    printf("has %d distinct components\n", $ccEngine->get_component_count);
    $cluster_root = $ccEngine->clusterset;

=cut

=head1 CONTACT

  Contact Jessica Severin on module implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Graph::ConnectedComponents;

use strict; 
use Bio::EnsEMBL::Compara::NestedSet;
use Time::HiRes qw(time gettimeofday tv_interval);

#new method inherited from CGObject which calls init

sub new {
  my $class = shift;
  
  my $self = {};
  bless $self,$class;
  
  $self->{'tree_root'} = new Bio::EnsEMBL::Compara::NestedSet;
  $self->{'tree_root'}->name("CC_clusterset");
    
  $self->{'member_leaves'} = {};
 
  return $self;
}

sub DESTROY {
  my $self = shift;
  
  $self->{'tree_root'}->cascade_unlink;
  $self->{'tree_root'} = undef;
}


=head2 add_connection

  Description: Takes a pair of unique scalars and uses the NestedSet objects
     to build a 3 layer tree in memory.  There is a single root for the entire build
     process, and each cluster is a child of this root.  The <scalars> are children of
     the clusters. 
  Arg [1]    : <scalar> node1 identifier (some unique number, name or object/data reference)
  Arg [2]    : <scalar> node2 identifier
  Example    : $ccEngine->add_connection(1234567, $member);
               $ccEngine->add_connection(1234567, "ENG00000076598");
  Returntype : undef
  Exceptions : none
  Caller     : general
    
=cut

sub add_connection {
  my $self = shift;
  my $node1_id = shift;
  my $node2_id = shift;
  
  my ($node1, $node2);
  $node1 = $self->{'member_leaves'}->{$node1_id};
  $node2 = $self->{'member_leaves'}->{$node2_id};

  if(!defined($node1)) {
    $node1 = new Bio::EnsEMBL::Compara::NestedSet;
    $node1->node_id($node1_id);
    $self->{'member_leaves'}->{$node1_id} = $node1;
  }
  if(!defined($node2)) {
    $node2 = new Bio::EnsEMBL::Compara::NestedSet;
    $node2->node_id($node2_id);
    $self->{'member_leaves'}->{$node2_id} = $node2;
  }
  
  my $parent1 = $node1->parent;
  my $parent2 = $node2->parent;
        
  if(!defined($parent1) and !defined($parent2)) {
    #neither member is in a cluster so create new cluster with just these 2 members
    # printf("create new cluster\n");
    my $cluster = new Bio::EnsEMBL::Compara::NestedSet;
    $self->{'tree_root'}->add_child($cluster);
    $cluster->add_child($node1);
    $cluster->add_child($node2);
  }
  elsif(defined($parent1) and !defined($parent2)) {
    # printf("add member to cluster %d\n", $parent1->node_id);
    # $node2->print_member; 
    $parent1->add_child($node2);
  }
  elsif(!defined($parent1) and defined($parent2)) {
    # printf("add member to cluster %d\n", $parent2->node_id);
    # $node1->print_member; 
    $parent2->add_child($node1);
  }
  elsif(defined($parent1) and defined($parent2)) {
    if($parent1->equals($parent2)) {
      # printf("both members already in same cluster %d\n", $parent1->node_id);
    } else {
      #these member already belong to a different clusters -> need to merge clusters
      # print("MERGE clusters\n");
      $parent1->merge_children($parent2);
      $parent2->disavow_parent; #releases from root
    }
  }
  my $link = undef;
  #$link = $node1->create_link_to_node($node2); #builds a cyclic connected graph of the connections
  return $link;
}


sub get_cluster_count {
  my $self = shift;
  return $self->{'tree_root'}->get_child_count;
}


sub get_component_count {
  my $self = shift;
  return scalar(keys(%{$self->{'member_leaves'}}));
}


sub clusterset {
  my $self = shift;
  return $self->{'tree_root'};
}

1;
