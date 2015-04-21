=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::Graph::Node

=head1 DESCRIPTION

Object oriented graph system which is based on Node and Link objects.  There is
no 'graph' object, the graph is constructed out of Nodes and Links, and the
graph is 'walked' from Node to Link to Node.  Can be used to represent any graph
structure from  DAGs (directed acyclic graph) to Trees to undirected cyclic Graphs.

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

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::Graph::Node;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::Graph::Link;

use base ('Bio::EnsEMBL::Compara::Taggable');


#################################################
# creation methods
#################################################

sub new {
  my ($class, @args) = @_;
  ## Allows to create a new object from an existing one with $object->new
  $class = ref($class) if (ref($class));
  my $self = {};
  bless $self,$class;
  $self->{'_node_id'} = undef;
  return $self;
}

sub copy {
  my $self = shift;
  
  my $mycopy = @_ ? shift : {};
  bless $mycopy, ref($self);

  $mycopy->{'_node_id'} = undef;

  if($self->{'_tags'}) {
    %{$mycopy->{'_tags'}} = %{$self->{'_tags'}};
  }
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
  
  #printf("Graph::Node::copy %d", $self);
  #printf(" from link %s", $incoming_link) if($incoming_link);
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
  return $self unless(defined($self->{'_node_id'}));
  return $self->{'_node_id'};
}

sub name {
  my $self = shift;
  my $value = shift;
  if(defined($value)) { $self->add_tag('name', $value); }
  else { $value = $self->get_tagvalue('name'); }
  return $value;
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

  assert_ref($node, 'Bio::EnsEMBL::Compara::Graph::Node');
  
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

sub create_directed_link_to_node {
  my $self = shift;
  my $node = shift;
  my $distance = shift;

  assert_ref($node, 'Bio::EnsEMBL::Compara::Graph::Node');
  
  #print("create_link_to_node\n");  $self->print_node; $node->print_node;
  
  my $link = $self->link_for_neighbor($node);
  return $link if($link);

  #results in calls to _add_neighbor_link_to_hash on each node
  $link = new Bio::EnsEMBL::Compara::Graph::Link($self, $node);
  if(defined($distance)) { 
    $link->distance_between($distance);
  }
  $link->{'_link_node2'}->_unlink_node_in_hash($link->{'_link_node1'});

  return $link;
}

#
# internal method called by Compara::Graph::Link
sub _add_neighbor_link_to_hash {
  my $self = shift;
  my $neighbor = shift;
  my $link = shift;
  
  $self->{'_obj_id_to_link'} = {} unless($self->{'_obj_id_to_link'});
  $self->{'_obj_id_to_link'}->{$neighbor} = $link;
}

sub _unlink_node_in_hash {
  my $self = shift;
  my $neighbor = shift;
  
  delete $self->{'_obj_id_to_link'}->{$neighbor};
}


=head2 unlink_neighbor

  Overview   : unlink and release neighbor from self if its mine
  Arg [1]    : $node Bio::EnsEMBL::Compara::Graph::Node instance
  Example    : $self->unlink_neighbor($node);
  Returntype : undef
  Caller     : general

=cut

sub unlink_neighbor {
  my ($self, $node) = @_;

  assert_ref($node, 'Bio::EnsEMBL::Compara::Graph::Node');

  my $link = $self->link_for_neighbor($node);  
  throw("$self not my neighbor $node") unless($link);
  $link->dealloc;

  return undef;
}


sub unlink_all {
  my $self = shift;

  foreach my $link (@{$self->links}) {
    $link->dealloc;
  }
  return undef;
}


=head2 cascade_unlink

  Overview   : release all neighbors and clear arrays and hashes
  Example    : $self->cascade_unlink
  Returntype : $self
  Exceptions : none
  Caller     : general

=cut

sub cascade_unlink {
  my $self = shift;
  my $caller = shift;

  no warnings qw/recursion/;

  #printf("cascade_unlink : "); $self->print_node;
  
  my @neighbors;
  foreach my $link (@{$self->links}) {
    my $neighbor = $link->get_neighbor($self);
    next if($caller and $neighbor->equals($caller));
    $link->dealloc;
    push @neighbors, $neighbor;
  }
 
  foreach my $neighbor (@neighbors) {
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
  
  $link1->dealloc;
  $link2->dealloc;
  
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

  assert_ref($node, 'Bio::EnsEMBL::Compara::Graph::Node');

  return $self->{'_obj_id_to_link'}->{$node};
}


sub print_node {
  my $self  = shift;
  printf("Node(%s)%s\n", $self, $self->name);
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
  return 1 if($self eq $other);
  return 0;
}

sub like {
  my $self = shift;
  my $other = shift;
  assert_ref($other, 'Bio::EnsEMBL::Compara::Graph::Node');
  return 1 if($self eq $other);
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
  
  assert_ref($node, 'Bio::EnsEMBL::Compara::Graph::Node');
  
  return 1 if(defined($self->{'_obj_id_to_link'}->{$node}));
  return 0;
}

sub neighbors {
  my $self = shift;

  my @neighbors;

  foreach my $link (@{$self->links}) {
    my $neighbor = $link->get_neighbor($self);
    push @neighbors, $neighbor;
  }

  return \@neighbors;
}

sub find_node_by_name {
  my $self = shift;
  my $name = shift;
  
  unless (defined $name) {
    throw("a name needs to be given as argument. The argument is currently undef\n");
  }
  return $self if($name eq $self->name);
 
  foreach my $neighbor (@{$self->_walk_graph_until(-name => $name)}) {
    return $neighbor if($name eq $neighbor->name);
  }

  return undef;
}

sub find_node_by_node_id {
  my $self = shift;
  my $node_id = shift;
  
  unless (defined $node_id) {
    throw("a node_id needs to be given as argument. The argument is currently undef\n");
  }
  return $self if($node_id eq $self->node_id);

  foreach my $neighbor (@{$self->_walk_graph_until(-node_id => $node_id)}) {
    return $neighbor if($node_id eq $neighbor->node_id);
  }
  
  return undef;
}

sub all_nodes_in_graph {
  my $self = shift;

  return $self->_walk_graph_until;
}

sub all_links_in_graph {
  my ($self, @args) = @_;
  my $cache_links;

  if (scalar @args) {
    ($cache_links) = 
      rearrange([qw(CACHE_LINKS)], @args);
  }

  no warnings qw/recursion/;

  unless (defined $cache_links) {
    $cache_links = {};
  }

  foreach my $link (@{$self->links}) {
    next if ($cache_links->{$link});
    $cache_links->{$link} = $link;
    my $neighbor = $link->get_neighbor($self);
    $neighbor->all_links_in_graph(-cache_links => $cache_links);
  }

  return [ values %{$cache_links} ];
}

sub _walk_graph_until {
  my ($self, @args) = @_;
  my $name;
  my $node_id;
  my $cache_nodes;

  if (scalar @args) {
    ($name, $node_id, $cache_nodes) = 
       rearrange([qw(NAME NODE_ID CACHE_NODES)], @args);
  }

  no warnings qw/recursion/;

  unless (defined $cache_nodes) {
    $cache_nodes = {};
    $cache_nodes->{$self} = $self;
  }

  foreach my $neighbor (@{$self->neighbors}) {
    next if ($cache_nodes->{$neighbor});
    $cache_nodes->{$neighbor} = $neighbor;
    last if (defined $name && $name eq $neighbor->name);
    last if (defined $node_id && $node_id eq $neighbor->node_id);
    $neighbor->_walk_graph_until(-name => $name, -node_id => $node_id, -cache_nodes => $cache_nodes);
  }

  return [ values %{$cache_nodes} ];
}

1;

