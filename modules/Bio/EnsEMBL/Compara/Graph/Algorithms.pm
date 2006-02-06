=head1 NAME

Algorithms - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

Collection of graph traversal algorithms

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::Graph::Algorithms;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::Graph::CGObject;
use Bio::EnsEMBL::Compara::Graph::Node;
use Bio::EnsEMBL::Compara::Graph::Link;

our @ISA = qw(Bio::EnsEMBL::Compara::Graph::CGObject);

###################################################
#
# basic directed graphs stats routines
#  
###################################################

=head2 calc_link_sum

  Arg [1]    : <Bio::EnsEMBL::Compara::Graph::Link> $link
  Arg [2]    : <Bio::EnsEMBL::Compara::Graph::Node> $node
  Example    : $sum = Bio::EnsEMBL::Compara::Graph::Algorithms::calc_link_sum($link, $next_node);
  Description: returns the sum of all the lengths of the links starting from node
  Returntype : Bio::EnsEMBL::Compara::Graph::Link
  Exceptions : none

=cut


sub calc_link_sum
{
  my $link = shift;
  my $to_node = shift;
  
  throw("node not part of link") unless($link and $to_node and $link->get_neighbor($to_node));
  return 0.0 if($to_node->is_leaf);
  my $link_sum = $link->distance_between;
  
  foreach my $next_link (@{$to_node->links}) {
    throw("failure: node has an undefined link") unless(defined($next_link));
    next if($link->equals($next_link));
    my $next_node = $next_link->get_neighbor($to_node);
    $link_sum += calc_link_sum($next_link, $next_node);
  }
  return $link_sum;
}


sub calc_node_count
{
  my $link = shift;
  my $to_node = shift;
  
  throw("node not part of link") unless($link and $to_node and $link->get_neighbor($to_node));
  return 1 if($to_node->is_leaf);
  
  my $node_count = 1; # for mylink;
  
  foreach my $next_link (@{$to_node->links}) {
    throw("failure: node has an undefined link") unless(defined($next_link));
    next if($link->equals($next_link));
    my $next_node = $next_link->get_neighbor($to_node);
    $node_count += calc_node_count($next_link, $next_node);
  }
  return $node_count;
}


sub calc_leaf_count
{
  my $link = shift;
  my $to_node = shift;
  
  throw("node not part of link") unless($link and $to_node and $link->get_neighbor($to_node));
  return 1 if($to_node->is_leaf);
  
  my $node_count = 0;
  
  foreach my $next_link (@{$to_node->links}) {
    throw("failure: node has an undefined link") unless(defined($next_link));
    next if($link->equals($next_link));
    my $next_node = $next_link->get_neighbor($to_node);
    $node_count += calc_leaf_count($next_link, $next_node);
  }
  return $node_count;
}



###################################################
#
# tree balancing algorithm
#   walks through graph starting at a link to find 
#   the link which bests balances the tree
#   Balance is defined as the sum of the link lengths
#   on each side of link 
###################################################

sub find_balanced_link
{
  my $link = shift;
  my $debug = shift;
  
  my $stats = {};
  my $visited_links = {};
  
  my $starttime = time();
  _internal_find_balanced_link($link, $visited_links, $stats, $debug);
  
  if($debug) {
    printf("%1.3f secs to run find_balanced_link\n", (time()-$starttime));
    
    printf("best balanced (%f - %f = %f) : ", 
       $stats->{'weight1'}, $stats->{'weight2'}, $stats->{'best_balance'}); 
     $stats->{'best_link'}->print_link;
    printf("  %d --- %d leaves\n",  $stats->{'leaves1'}, $stats->{'leaves2'});
  }
    
  return $stats->{'best_link'};
}


sub _internal_find_balanced_link
{
  my $link = shift;
  my $visited_links = shift;
  my $stats = shift;
  my $debug = shift;
    
  return if(defined($visited_links->{$link->obj_id}));

  $visited_links->{$link->obj_id} = 1;
  
  my ($node1, $node2) = $link->get_nodes;
  
  my $weight1 = calc_link_sum($link, $node1);
  my $weight2 = calc_link_sum($link, $node2);
  my $balance = abs($weight1 - $weight2);
  
  if($debug) {
    printf("balance (%f - %f = %f) : ", $weight1, $weight2, $balance); 
    $link->print_link;
  }

  if(!defined($stats->{'best_balance'}) or ($balance < $stats->{'best_balance'})) {
    $stats->{'best_balance'} = $balance;
    $stats->{'weight1'} = $weight1;
    $stats->{'weight2'} = $weight2;
    $stats->{'leaves1'} = calc_leaf_count($link, $node1);
    $stats->{'leaves2'} = calc_leaf_count($link, $node2);
    $stats->{'best_link'} = $link;
  }
  
  my $heavier_node = $node1;
  if($weight2 > $weight1) { $heavier_node = $node2;}
  
  foreach my $next_link (@{$heavier_node->links}) {
    throw("failure: node has an undefined link") unless(defined($next_link));
    next if($link->equals($next_link));
    _internal_find_balanced_link($next_link, $visited_links, $stats, $debug);
  }
  return undef;
}


########################################################
#
# convert graph into rooted tree (NestedSet)
#
########################################################

sub root_tree_on_link
{
  my $link = shift;
  
  my ($node1, $node2) = $link->get_nodes;

  parent_graph($node1);
  parent_graph($node2);

  my $dist = $link->distance_between;

  my $root = new Bio::EnsEMBL::Compara::NestedSet;
  $root->add_child($node1, $dist / 2.0);
  $root->add_child($node2, $dist / 2.0);

  parent_graph($root);

  return $root;
}


sub parent_graph {
  my $node = shift;
  my $parent_link = shift;
  
  return undef unless($node);
    
  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    bless $node, "Bio::EnsEMBL::Compara::NestedSet";
  }
  $node->_set_parent_link($parent_link);

  foreach my $next_link (@{$node->links}) {
    throw("failure: node has an undefined link") unless(defined($next_link));
    next if($parent_link and $parent_link->equals($next_link));
    my $next_node = $next_link->get_neighbor($node);
    parent_graph($next_node, $next_link);
  }
}


###################################################
#
# tree balancing algorithm
#   find new root which minimizes least sum of squares 
#   distance to root
#
###################################################

sub balance_tree
{
  my $tree = shift;
  
  my $starttime = time();
  
  my $last_root = Bio::EnsEMBL::Compara::NestedSet->new;
  $last_root->merge_children($tree);
  
  my $best_root = $last_root;
  my $best_weight = calc_tree_weight($last_root);
  
  my @all_nodes = $last_root->get_all_subnodes;
  
  foreach my $node (@all_nodes) {
    $node->re_root;
    $last_root = $node;
    
    my $new_weight = calc_tree_weight($node);
    if($new_weight < $best_weight) {
      $best_weight = $new_weight;
      $best_root = $node;
    }
  }
  printf("%1.3f secs to run balance_tree\n", (time()-$starttime));

  $best_root->re_root;
  $tree->merge_children($best_root);
}

sub calc_tree_weight
{
  my $tree = shift;

  my $weight=0.0;
  foreach my $node (@{$tree->get_all_leaves}) {
    my $dist = $node->distance_to_root;
    $weight += $dist * $dist;
  }
  return $weight;  
}



####################################################
#
# tree chopping
#
####################################################

sub chop_tree
{
  my $tree = shift;
  
  printf("chop_tree\n");
  my $all_links = get_all_links($tree);
  printf("%d links in graph\n", scalar(@$all_links));  
    
  my @sortedlinks = 
     sort { $b->distance_between <=> $a->distance_between     
          } @{$all_links;};
  my $count = 0;
  foreach my $link (@sortedlinks) {
    $count++;
    $link->print_link;
    
    my ($node1, $node2) = $link->get_nodes;
    my $weight1 = calc_link_sum($link, $node1);
    my $weight2 = calc_link_sum($link, $node2);
    my $leafcount1 = calc_leaf_count($link, $node1);
    my $leafcount2 = calc_leaf_count($link, $node2);

    printf("  link dist balance (%7.5f --- %7.5f)\n", $weight1, $weight2);
    printf("  leaf counts       (%8d --- %8d)\n", $leafcount1, $leafcount2);
    
    if($leafcount1 >75 and $leafcount2>75) {
      printf("%d link is ok to break\n", $count);
      last;
    }
  }
  
}


sub get_all_links
{
  my $obj = shift;
  
  my $starttime = time();
  my $visited_links = {};

  return undef unless($obj);
  
  my $link=undef;
  if($obj->isa("Bio::EnsEMBL::Compara::Graph::Link")) {
    $link = $obj;
  }
  if($obj->isa("Bio::EnsEMBL::Compara::Graph::Node")) {
    ($link) = @{$obj->links};
  }
  return undef unless($link);

  _internal_get_all_links($link, $visited_links);
  printf("%1.3f secs to run get_all_links\n", (time()-$starttime));
  
  my @links = values(%{$visited_links});
  return \@links;
}


sub _internal_get_all_links
{
  my $link = shift;
  my $visited_links = shift;
    
  return if(defined($visited_links->{$link->obj_id}));

  $visited_links->{$link->obj_id} = $link;
  
  my ($node1, $node2) = $link->get_nodes;
  
  foreach my $next_link (@{$node1->links}) {
    next if($next_link->equals($link));
    _internal_get_all_links($next_link, $visited_links);
  }

  foreach my $next_link (@{$node2->links}) {
    next if($next_link->equals($link));
    _internal_get_all_links($next_link, $visited_links);
  }

  return undef;
}


1;

