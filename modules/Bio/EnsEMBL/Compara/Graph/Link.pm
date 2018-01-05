=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::Graph::Link

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

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::Graph::Link;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use base ('Bio::EnsEMBL::Compara::Taggable');

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

  assert_ref($node1, 'Bio::EnsEMBL::Compara::Graph::Node', 'node1');
  assert_ref($node2, 'Bio::EnsEMBL::Compara::Graph::Node', 'node2');

  my $self = {};
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
  
  return $self->{'_link_node2'} if($node eq $self->{'_link_node1'});
  return $self->{'_link_node1'} if($node eq $self->{'_link_node2'});
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
  #assert_ref($other, 'Bio::EnsEMBL::Compara::Graph::Link', 'other');
  return 1 if($self eq $other);
  return 0;
}

sub print_link {
  my $self  = shift;
  printf("link(%s): (%s)-- %1.5f --(%s)\n", 
      $self, 
      $self->{'_link_node1'}->node_id,
      $self->distance_between,
      $self->{'_link_node2'}->node_id,
    );
}


1;

