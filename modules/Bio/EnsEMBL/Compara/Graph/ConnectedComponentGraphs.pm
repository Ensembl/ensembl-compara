#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Graph::ConnectedComponentGraphs

=cut

=head1 SYNOPSIS

my $ccgEngine = new Bio::EnsEMBL::Compara::Graph::ConnectedComponentGraphs;
my $link = $ccgEngine->add_connection($node_id1, $node_id2);
$link->add_tag("my_tag","my_value");

my $holding_node = $ccgEngine->holding_node;

foreach my $link (@{$holding_node->links}) {
  my $graph = $link->get_neighbor($holding_node);
}

=cut

=head1 DESCRIPTION

This is a general purpose tool for building connected component graphs
from pairs of scalars. The scalars can be any perl scalar (number, string,
object reference, hash reference, list reference) The scalars are treated as
distinct IDs so that equal scalars point to the same node/component.
As new scalar IDs are encountered new nodes are created and graphs are grown
and merged as the connections are added.  It uses the Node data structure.
typical use would be
    my $ccgEngine = new Bio::EnsEMBL::Compara::Graph::ConnectedComponentGraphs;
    foreach my($node_id1, $node_id2) (@some_list_of_pairs) {
      $ccgEngine->add_connection($node_id1, $node_id2);
    }
    printf("built %d graphs\n", $ccEngine->get_graph_count);
    printf("has %d distinct components\n", $ccEngine->get_component_count);
    $graph_holding_node = $ccEngine->holding_node;

The holding node has a hard coded name 'ccg_holding_node' that can be
retrieved by $graph_holding_node->name, or find from any node in a graph
using $current_node->find_node_by_name('ccg_holding_node');

The holding node has links to graph nodes, each of which is a single entry
point to an independant graph. This entry node (and there is only one for each graph)
have a special name 'connected_to_holding_node', and can be found from any node in a
graph using $current_node->find_node_by_name('connected_to_holding_node');

=cut

=head1 CONTACT

  Contact Abel Ureta-Vidal on module implemetation/design detail: abel@ebi.ac.uk
  or more generally ensembl-dev@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Graph::ConnectedComponentGraphs;

use strict; 
use Bio::EnsEMBL::Compara::Graph::Node;
use Time::HiRes qw(time gettimeofday tv_interval);

sub new {
  my $class = shift;
  
  my $self = {};
  bless $self,$class;
  
  $self->{'holding_node'} = new Bio::EnsEMBL::Compara::Graph::Node;
  $self->{'holding_node'}->name("ccg_holding_node");
    
  $self->{'cache_nodes'} = {};
 
  return $self;
}

sub DESTROY {
  my $self = shift;
  
  $self->{'holding_node'}->cascade_unlink;
  $self->{'holding_node'} = undef;
}

=head2 add_connection

  Arg [1]    : <scalar> node1 identifier (some unique number, name or object/data reference)
  Arg [2]    : <scalar> node2 identifier
  Example    : $ccgEngine->add_connection($id1, $id2);
               $ccgEngine->add_connection($member1, $member2);
               $ccgEngine->add_connection("ENG00000016598", "ENG00000076598");
  Description: Takes a pair of unique scalars and uses the Node objects to build graphs in memory.
               There is a single graph holding node for the entire build process, and each independant
               graph has a single node connected to this "holding" node.
  Returntype : Bio::EnsEMBL::Compara::Graph::Link
  Exceptions : none
  Caller     : general
    
=cut

sub add_connection {
  my $self = shift;
  my $node1_id = shift;
  my $node2_id = shift;
  
  my ($node1, $node2);
  $node1 = $self->{'cache_nodes'}->{$node1_id};
  $node2 = $self->{'cache_nodes'}->{$node2_id};

  if (defined $node1 && defined $node2) {
    if ($node1->has_neighbor($node2)) {
      #link exist already return it
      return $node1->link_for_neighbor($node2);
    } else {
      #needs to merge 2 graphs, undef one of the nodes connected to the holding node
      my $connected_to_holding_node = $node2->find_node_by_name('connected_to_holding_node');
      $connected_to_holding_node->name("");
      #break link with holding_node
      $connected_to_holding_node->unlink_neighbor($self->{'holding_node'});
#      another way to do it in 2 lines
#      my $holding_link = $connected_to_holding_node->link_for_neighbor($self->{'holding_node'});
#      $holding_link->dealloc;

      #link does not exit, creates it 
      my $link = $node1->create_link_to_node($node2);
      return $link
    }
  }

  my $node1_was_undef = 0;

  if(!defined($node1)) {
    $node1 = new Bio::EnsEMBL::Compara::Graph::Node;
    $node1->node_id($node1_id);
    $self->{'cache_nodes'}->{$node1_id} = $node1;
    $node1_was_undef = 1;
    if (defined $node2) {
      my $link = $node1->create_link_to_node($node2);
      return $link;
    }
  }
  if(!defined($node2)) {
    $node2 = new Bio::EnsEMBL::Compara::Graph::Node;
    $node2->node_id($node2_id);
    $self->{'cache_nodes'}->{$node2_id} = $node2;
    if ($node1_was_undef) {
      # both node were undef, connect one of them to the holding_node
      $node1->name("connected_to_holding_node");
      $node1->create_link_to_node($self->{'holding_node'});
    }
    my $link = $node1->create_link_to_node($node2);
    return $link;
  }
}

=head2 get_graph_count

  Arg [1]    : none
  Example    : $ccgEngine->get_graph_count;
  Description: return the number of independant graphs currently in memory
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub get_graph_count {
  my $self = shift;
  return scalar @{$self->{'holding_node'}->links};
}

=head2 get_component_count

  Arg [1]    : none
  Example    : $ccgEngine->get_component_count;
  Description: return the number of nodes involved in the graphs currently in memory
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub get_component_count {
  my $self = shift;
  return scalar(keys(%{$self->{'cache_nodes'}}));
}

=head2 holding_node

  Arg [1]    : none
  Example    : $ccgEngine->holding_node;
  Description: return the node that hold links to each graph currently in memory
  Returntype : Bio::EnsEMBL::Compara::Graph::Node
  Exceptions : none
  Caller     : general

=cut

sub holding_node {
  my $self = shift;
  return $self->{'holding_node'};
}

=head2 graphs

  Arg [1]    : none
  Example    : $ccgEngine->graphs;
  Description: return the array reference of nodes, each of them is the entry point
               to an individual independant graph.
  Returntype : array reference of Bio::EnsEMBL::Compara::Graph::Node
  Exceptions : none
  Caller     : general

=cut

sub graphs {
  my $self = shift;

  my @graphs;
  foreach my $link (@{$self->{'holding_node'}->links}) {
    my $node = $link->get_neighbor($self->{'holding_node'});
    push @graphs, $node;
  }

  return \@graphs;
}

1;
