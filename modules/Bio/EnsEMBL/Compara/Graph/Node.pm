=head1 NAME

Node - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

Abstract superclass to encapsulate the process of storing and manipulating a
nested-set representation tree.  Also implements a 'reference count' system 
based on the ObjectiveC retain/release design. 
Designed to be used as the Root class for all Compara 'proxy' classes 
(Member, GenomeDB, DnaFrag, NCBITaxon) to allow them to be made into sets and trees.

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::Graph::Node;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Compara::Graph::Link;

our @ISA = qw(Bio::EnsEMBL::Compara::Graph::CGObject);

#################################################
# creation methods
#################################################

#new and alloc method in superclass

sub init {
  my $self = shift;
   $self->SUPER::init;
  return $self;
}

sub dealloc {
  my $self = shift;
  #$self->unlink_all_neighbors;
  return $self->SUPER::dealloc;
}

sub copy {
  my $self = shift;
  
  my $mycopy = $self->SUPER::copy;
  bless $mycopy, "Bio::EnsEMBL::Compara::Graph::Node";
  return $mycopy;
}

sub copy_shallow_links {
  my $self = shift;
  
  my $mycopy = $self->copy;
  
  #copies links to all my neighbors but does not recurse beyond
  foreach my $link (@{$self->links}) {
    $mycopy->create_link_to_node($link->get_neighbor($self), 
                                 $link->distance_between);
  }  
  
  return $mycopy;
}

sub copy_graph {
  my $self = shift;
  my $incoming_link = shift;
  
  my $mycopy = $self->copy;
  
  #printf("Graph::Node::copy %d", $self->obj_id);
  #printf(" from link %s", $incoming_link->obj_id) if($incoming_link);
  #print("\n");
  
  foreach my $link (@{$self->links}) {
    next if($incoming_link and $link->equals($incoming_link));
    my $newnode = $link->get_neighbor($self)->copy_graph($link);
    $mycopy->create_link_to_node($newnode, $link->distance_between);
  }  
    
  return $mycopy;
}

#################################################
#
# get/set variable methods
#
#################################################

=head2 node_id

  Arg [1]    : (opt.) integer node_id
  Example    : my $nsetID = $object->node_id();
  Example    : $object->node_id(12);
  Description: Getter/Setter for the node_id of this object in the database
  Returntype : integer node_id
  Exceptions : none
  Caller     : general

=cut

sub node_id {
  my $self = shift;
  $self->{'_node_id'} = shift if(@_);
  return $self->obj_id unless(defined($self->{'_node_id'}));
  return $self->{'_node_id'};
}



#######################################
# Set manipulation methods
#######################################

=head2 create_link_to_node

  Overview   : attaches neighbor Graph::Node to this nested set
  Arg [1]    : Bio::EnsEMBL::Compara::Graph::Node $node
  Arg [2]    : (opt.) <float> distance to node
  Example    : $self->add_child($node);
  Returntype : Compara::Graph::Link object
  Exceptions : if neighbor is undef or not a NestedSet subclass
  Caller     : general

=cut

sub create_link_to_node {
  my $self = shift;
  my $node = shift;
  my $distance = shift;

  throw("neighbor not defined") 
     unless(defined($node));
  throw("arg must be a [Bio::EnsEMBL::Compara::Graph::Node] not a [$node]")
     unless($node->isa('Bio::EnsEMBL::Compara::Graph::Node'));
  
  #print("create_link_to_node\n");  $self->print_node; $node->print_node;
  
  my $link = $self->link_for_neighbor($node);
  return $link if($link);

  #results in calls to _add_neighbor_link_to_hash on each node
  $link = new Bio::EnsEMBL::Compara::Graph::Link($self, $node);
  if(defined($distance)) { 
    $link->distance_between($distance);
  }
  return $link;
}

#
# internal method called by Compara::Graph::Link
sub _add_neighbor_link_to_hash {
  my $self = shift;
  my $neighbor = shift;
  my $link = shift;
  
  $self->{'_obj_id_to_link'} = {} unless($self->{'_obj_id_to_link'});
  $self->{'_obj_id_to_link'}->{$neighbor->obj_id} = $link;
}

sub _unlink_node_in_hash {
  my $self = shift;
  my $neighbor = shift;
  
  delete $self->{'_obj_id_to_link'}->{$neighbor->obj_id};
}


=head2 unlink_neighbor

  Overview   : unlink and release neighbor from self if its mine
               might cause neighbor to delete if refcount reaches Zero.
  Arg [1]    : $node Bio::EnsEMBL::Compara::Graph::Node instance
  Example    : $self->unlink_neighbor($node);
  Returntype : undef
  Caller     : general

=cut

sub unlink_neighbor {
  my ($self, $node) = @_;

  throw("neighbor not defined") unless(defined($node));
  throw("arg must be a [Bio::EnsEMBL::Compara::Graph::Node] not a [$node]")
     unless($node->isa('Bio::EnsEMBL::Compara::Graph::Node'));

  my $link = $self->link_for_neighbor($node);  
  throw($self->obj_id. " not my neighbor ". $node->obj_id) unless($link);
  $link->release;  

  return undef;
}


sub unlink_all {
  my $self = shift;

  foreach my $link (@{$self->links}) {
    $link->release;
  }
  return undef;
}


=head2 cascade_unlink

  Overview   : release all neighbors and clear arrays and hashes
               will cause potential deletion of neighbors if refcount reaches Zero.
  Example    : $self->release_neighbors
  Returntype : $self
  Exceptions : none
  Caller     : general

=cut

sub cascade_unlink {
  my $self = shift;
  my $caller = shift;
  
  #printf("cascade_unlink : "); $self->print_node;
  if($self->refcount > $self->link_count) {
    printf("!!!! node is being retained - can't cascade_unlink\n");
    return undef;
  }
  
  foreach my $link (@{$self->links}) {
    my $neighbor = $link->get_neighbor($self);
    next if($caller and $neighbor->equals($caller));
    $link->release;
    $neighbor->cascade_unlink($self);
  }
  
  return $self;
}


sub minimize_node {
  my $self = shift;
  
  return $self unless($self->link_count() == 2);

  #printf("Node::minimize_node "); $self->print_node;
  my ($link1, $link2) = @{$self->links};
  my $dist = $link1->distance_between + $link2->distance_between;
  my $node1 = $link1->get_neighbor($self);
  my $node2 = $link2->get_neighbor($self);
  
  new Bio::EnsEMBL::Compara::Graph::Link($node1, $node2, $dist);
  
  $link1->release;
  $link2->release;  
  
  return undef;
}

=head2 links

  Overview   : returns a list of Compara::Graph::Link connected to this node
  Example    : my @links = @{self->links()};
  Returntype : array reference of Bio::EnsEMBL::Compara::Graph::Link objects (could be empty)
  Exceptions : none
  Caller     : general

=cut

sub links {
  my $self = shift;

  return [] unless($self->{'_obj_id_to_link'});
  my @links = values(%{$self->{'_obj_id_to_link'}});
  return \@links;
}


sub link_for_neighbor {
  my $self = shift;
  my $node = shift;

  throw("arg must be a [Bio::EnsEMBL::Compara::Graph::Node] not a [$node]")
     unless($node and $node->isa('Bio::EnsEMBL::Compara::Graph::Node'));

  return $self->{'_obj_id_to_link'}->{$node->obj_id};
}


sub print_node {
  my $self  = shift;
  printf("Node(%s)%s\n", $self->obj_id, $self->name);
}


sub print_links {
  my $self  = shift;
  foreach my $link (@{$self->links}) {
    $link->print_link;
  }
}


sub link_count {
  my $self = shift;
  return scalar(@{$self->links});
}


sub is_leaf {
  my $self = shift;
  return 1 if($self->link_count <= 1);
  return 0;
}



##################################
#
# simple search methods
#
##################################

sub equals {
  my $self = shift;
  my $other = shift;
  #throw("arg must be a [Bio::EnsEMBL::Compara::Graph::Node] not a [$other]")
  #      unless($other and $other->isa('Bio::EnsEMBL::Compara::Graph::Node'));
  return 1 if($self->obj_id eq $other->obj_id);
  return 0;
}

sub like {
  my $self = shift;
  my $other = shift;
  throw("arg must be a [Bio::EnsEMBL::Compara::Graph::Node] not a [$other]")
        unless($other and $other->isa('Bio::EnsEMBL::Compara::Graph::Node'));
  return 1 if($self->obj_id eq $other->obj_id);
  return 0 unless($self->link_count == $other->link_count);
  foreach my $link (@{$self->links}) {
    my $node = $link->get_neighbor($self);
    return 0 unless($other->has_neighbor($node));
  }
  return 1;
}

sub has_neighbor {
  my $self = shift;
  my $node = shift;
  
  throw "[$node] must be a Bio::EnsEMBL::Compara::Graph::Node object"
       unless ($node and $node->isa("Bio::EnsEMBL::Compara::Graph::Node"));
  
  return 1 if(defined($self->{'_obj_id_to_link'}->{$node->obj_id}));
  return 0;
}


1;

