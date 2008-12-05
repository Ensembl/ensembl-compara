=head1 NAME

Link - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

Object oriented graph system which is based on Node and Link objects.  There is
no 'graph' object, the graph is constructed out of Nodes and Links, and the
graph is 'walked' from Node to Link to Node.  Can be used to represent any graph
structure from DAGs (directed acyclic graph) to Trees to undirected cyclic Graphs.

The system is fully connected so from any object in the graph one can 'walk' to
any other.  Links contain pointers to the nodes on either side (called neighbors),
and each Node contains a list of the links it is connected to.  
Nodes also keep hashes of their neighbors for fast 'set theory' operations.  
This graph system is used as the foundation for the Nested-set 
(Compara::NestedSet) system for storing trees in the compara database.

System has a simple API based on creating Nodes and then linking them together:
  my $node1 = new Bio::EnsEMBL::Compara::Graph::Node;
  my $node2 = new Bio::EnsEMBL::Compara::Graph::Node;
  new Bio::EnsEMBL::Compara::Graph::Link($node1, $node2, $distance_between);
And to 'disconnect' nodes, one just breaks a link;
  my $link = $node1->link_for_neighbor($node2);
  $link->dealloc;
Convenience methods to simplify this process
  $node1->create_link_to_node($node2, $distance_between);
  $node2->unlink_neighbor($node1);
  
=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::Graph::Link;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Compara::Graph::CGObject;

our @ISA = qw(Bio::EnsEMBL::Compara::Graph::CGObject);

#################################################
# Factory methods
#################################################

=head2 new

  Arg [1]    : <Bio::EnsEMBL::Compara::Graph::Node> node1
  Arg [2]    : <Bio::EnsEMBL::Compara::Graph::Node> node2
  Arg [3]    : (opt.) <float> length of link
  Example    : $link = new Bio::EnsEMBL::Compara::Graph::Link($node1, $node2);
  Description: creates new link between nodes
  Returntype : Bio::EnsEMBL::Compara::Graph::Link
  Exceptions : none

=cut

sub new {
  my $class = shift;
  my $node1 = shift;
  my $node2 = shift;
  my $dist = shift;

  throw("arg1 must be a [Bio::EnsEMBL::Compara::Graph::Node] not a [$node1]")
        unless(defined($node1) and $node1->isa('Bio::EnsEMBL::Compara::Graph::Node'));
  throw("arg2 must be a [Bio::EnsEMBL::Compara::Graph::Node] not a [$node2]")
        unless(defined($node2) and $node2->isa('Bio::EnsEMBL::Compara::Graph::Node'));

  my $self = $class->SUPER::new;
  bless $self, "Bio::EnsEMBL::Compara::Graph::Link";

  $self->{'_link_node1'} = $node1;
  $self->{'_link_node2'} = $node2;
  
  $node1->_add_neighbor_link_to_hash($node2, $self);
  $node2->_add_neighbor_link_to_hash($node1, $self);
  
  $self->distance_between($dist) if(defined($dist));
  return $self;
}


sub dealloc {
  my $self = shift;
  
  $self->{'_link_node1'}->_unlink_node_in_hash($self->{'_link_node2'});
  $self->{'_link_node2'}->_unlink_node_in_hash($self->{'_link_node1'});

  $self->{'_link_node1'} = undef;
  $self->{'_link_node2'} = undef;
  
  #printf("DEALLOC link refcount:%d ", $self->refcount);
}


# copy system is based that the nodes make the copies
# and the link just links (retains) 
sub copy {
  my $self = shift;
  
  my ($node1, $node2) = $self->get_nodes;
  my $mycopy = new Bio::EnsEMBL::Compara::Graph::Link($node1, $node2);
  $mycopy->distance_between($self->distance_between);

  return $mycopy;
}

=head2 get_nodes

  Example    : ($node1, $node2) = $link->get_nodes;
  Description: returns the nodes as an unordered list
  Returntype : undef
  Exceptions : none

=cut

sub get_nodes {
  my $self = shift;
  return ($self->{'_link_node1'}, $self->{'_link_node2'});
}

=head2 get_neighbor

  Example    : $node2 = $link->get_neighbor($node1);
  Description: returns the other node in a link given a node.  return undef if $node1 
               is not part of the link.
  Returntype : Bio::EnsEMBL::Compara::Graph::Node or undef
  Exceptions : none

=cut

sub get_neighbor {
  my $self = shift;
  my $node = shift;
  
  return $self->{'_link_node2'} if($node->equals($self->{'_link_node1'}));
  return $self->{'_link_node1'} if($node->equals($self->{'_link_node2'}));
  return undef;
}

=head2 distance_between

  Arg [1]    : (opt.) <int or double> distance
  Example    : my $dist = $link->distance_between();
  Example    : $link->distance_between(1.618);
  Description: Getter/Setter for the distance between the nodes
  Returntype : <int or double> distance
  Exceptions : none
  Caller     : general

=cut

sub distance_between {
  my $self = shift;
  $self->{'_distance_between'} = shift if(@_);
  $self->{'_distance_between'} = 0.0 unless(defined($self->{'_distance_between'}));
  return $self->{'_distance_between'};
}

sub equals {
  my $self = shift;
  my $other = shift;
#  throw("arg must be a [Bio::EnsEMBL::Compara::Graph::Link] not a [$other]")
#        unless($other and $other->isa('Bio::EnsEMBL::Compara::Graph::Link')); # BEWARE speed up change uncommented
  return 1 if($self->obj_id eq $other->obj_id); # BEWARE speed up change below
  # return 1 if($self->{'_cgobject_id'} eq $other->{'_cgobject_id'});
  return 0;
}

sub print_link {
  my $self  = shift;
  printf("link(%s): (%s)-- %1.5f --(%s)\n", 
      $self->obj_id, 
      $self->{'_link_node1'}->node_id,
      $self->distance_between,
      $self->{'_link_node2'}->node_id,
    );
}


1;

