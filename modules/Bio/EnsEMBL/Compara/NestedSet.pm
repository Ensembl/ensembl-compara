=head1 NAME

NestedSet - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

Abstract superclass to encapsulate the process of storing and manipulating a
nested-set representation tree.  Also implements a 'reference count' system 
based on the ObjectiveC retain/release design. 
Designed to be used as the Root class for all Compara 'proxy' classes 
(Member, GenomeDB, DnaFrag, NCBITaxon) to allow them to be made into sets and trees.

=head1 CONTACT

  Contact Albert Vilella on implementation detail: avilella@ebi.ac.uk
  Contact Jessica Severin on implementation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::NestedSet;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

use Bio::EnsEMBL::Compara::Graph::Node;
our @ISA = qw(Bio::EnsEMBL::Compara::Graph::Node);

#################################################
# Factory methods
#################################################

sub init {
  my $self = shift;
  $self->SUPER::init;
  return $self;
}

sub dealloc {
  my $self = shift;

  #printf("DEALLOC NestedSet refcount:%d ", $self->refcount); $self->print_node;
  #$self->release_children;
  return $self->SUPER::dealloc;
}

=head2 copy

  Overview   : creates copy of tree starting at this node going down
  Example    : my $clone = $self->copy;
  Returntype : Bio::EnsEMBL::Compara::NestedSet
  Exceptions : none
  Caller     : general

=cut

sub copy {
  my $self = shift;
  
  my $mycopy = $self->SUPER::copy; 
  bless $mycopy, ref $self;

  $mycopy->distance_to_parent($self->distance_to_parent);
  $mycopy->left_index($self->left_index);
  $mycopy->right_index($self->right_index);

  foreach my $child (@{$self->children}) {  
    $mycopy->add_child($child->copy);
  }
  return $mycopy;
}


=head2 release_tree

  Overview   : deletes and frees the memory used by this tree
               and all the underlying nodes.
  Example    : $self->release_tree;
  Returntype : undef
  Exceptions : none
  Caller     : general

=cut

sub release_tree {
  my $self = shift;
  
  my $child_count = $self->get_child_count;
  $self->disavow_parent;
  $self->cascade_unlink if($child_count);
  return undef;
}

#################################################
# Object variable methods
#################################################

sub left_index {
  my $self = shift;
  $self->{'_left_index'} = shift if(@_);
  $self->{'_left_index'} = 0 unless(defined($self->{'_left_index'}));
  return $self->{'_left_index'};
}

sub right_index {
  my $self = shift;
  $self->{'_right_index'} = shift if(@_);
  $self->{'_right_index'} = 0 unless(defined($self->{'_right_index'}));
  return $self->{'_right_index'};
}


#######################################
# Set manipulation methods
#######################################

=head2 add_child

  Overview   : attaches child nestedset node to this nested set
  Arg [1]    : Bio::EnsEMBL::Compara::NestedSet $child
  Arg [2]    : (opt.) distance between this node and child
  Example    : $self->add_child($child);
  Returntype : undef
  Exceptions : if child is undef or not a NestedSet subclass
  Caller     : general

=cut

sub add_child {
  my $self = shift;
  my $child = shift;
  my $dist = shift;
  
  throw("child not defined") 
     unless(defined($child));
  throw("arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a [$child]")
     unless($child->isa('Bio::EnsEMBL::Compara::NestedSet'));
  
  #printf("add_child: parent(%s) <-> child(%s)\n", $self->node_id, $child->node_id);
  
  unless(defined($dist)) { $dist = $child->_distance; }

  $child->disavow_parent;
  #create_link_to_node is a safe method which checks if connection exists
  my $link = $self->create_link_to_node($child);
  $child->_set_parent_link($link);
  $self->{'_children_loaded'} = 1; 
  $link->distance_between($dist);
  return $link;
}

sub store_child {
  my ($self, $child) = @_;
  throw("store_child has been deprecated. Highly inefficient.".
        "Use add_child, build in memory and store in one go\n");
}


=head2 disavow_parent

  Overview   : unlink and release self from its parent
               might cause self to delete if refcount reaches Zero.
  Example    : $self->disavow_parent
  Returntype : undef
  Caller     : general

=cut

sub disavow_parent {
  my $self = shift;

  if($self->{'_parent_link'}) {
    my $link = $self->{'_parent_link'};
    #print("DISAVOW parent : "); $parent->print_node;
    #print("        child  : "); $self->print_node;
    $link->dealloc;
  }
  $self->_set_parent_link(undef);
  return undef;
}


=head2 release_children

  Overview   : recursive releases all children
               will cause potential deletion of children if refcount reaches Zero.
  Example    : $self->release_children
  Returntype : $self
  Exceptions : none
  Caller     : general

=cut

sub release_children {
  my $self = shift;
  
  # by calling with parent, this preserved the link to the parent
  # and thus doesn't unlink self
  foreach my $child (@{$self->children}) {
    $child->disavow_parent;
    $child->release_children;
  }
  #$self->cascade_unlink($self->{'_parent_node'});
  return $self;
}


=head2 parent

  Overview   : returns the parent NestedSet object for this node
  Example    : my $my_parent = $object->parent();
  Returntype : undef or Bio::EnsEMBL::Compara::NestedSet
  Exceptions : none
  Caller     : general

=cut

sub parent {
  my $self = shift;
  if(!defined($self->{'_parent_link'}) and $self->adaptor and $self->_parent_id) {
    my $parent = $self->adaptor->fetch_parent_for_node($self);
    #print("fetched parent : "); $parent->print_node;
    $parent->add_child($self);
  }
  return undef unless($self->{'_parent_link'});
  return $self->{'_parent_link'}->get_neighbor($self);
}

sub parent_link {
  my $self = shift;
  return $self->{'_parent_link'};
}

sub has_parent {
  my $self = shift;
  return 1 if($self->{'_parent_link'} or $self->_parent_id);
  return 0;
}


sub has_ancestor {
  my $self = shift;
  my $ancestor = shift;
  throw "[$ancestor] must be a Bio::EnsEMBL::Compara::NestedSet object"
       unless ($ancestor and $ancestor->isa("Bio::EnsEMBL::Compara::NestedSet"));
  my $node = $self->parent;
  while($node) {
    return 1 if($node->equals($ancestor));
    $node = $node->parent;
  }
  return 0;
}


=head2 root

  Overview   : returns the root NestedSet object for this node
               returns $self if node has no parent (this is the root)
  Example    : my $root = $object->root();
  Description: Returns the root of the tree for this node
               with links to all the intermediate nodes. Sister nodes
               are not included in the result.
  Returntype : undef or Bio::EnsEMBL::Compara::NestedSet
  Exceptions : none
  Caller     : general

=cut

sub root {
  my $self = shift;

  if (!defined($self->{'_parent_link'}) and $self->adaptor) {
    return $self->adaptor->fetch_root_by_node($self);
  }

  return $self unless(defined($self->parent));
 #  return $self if($self->node_id eq $self->parent->node_id);
  return $self->parent->root;
}

sub subroot {
  my $self = shift;

  return undef unless($self->parent);
  return $self unless(defined($self->parent->parent));
  return $self->parent->subroot;
}


=head2 children

  Overview   : returns a list of NestedSet nodes directly under this parent node
  Example    : my @children = @{$object->children()};
  Returntype : array reference of Bio::EnsEMBL::Compara::NestedSet objects (could be empty)
  Exceptions : none
  Caller     : general
  Algorithm  : new algorithm for fetching children:
                for each link connected to this NestedsSet node, a child is defined if
                  old: the link is not my parent_link
                  new: the link's neighbors' parent_link is the link
               This allows one (with a carefully coded algorithm) to overlay a tree on top
               of a fully connected graph and use the parent/children methods of NestedSet
               to walk the 'tree' substructure of the graph.  
               Trees that are really just trees are still trees.

=cut

sub children {
  my $self = shift;
  $self->load_children_if_needed;
  my @kids;
  foreach my $link (@{$self->links}) {
    next unless(defined($link));
    my $neighbor = $link->get_neighbor($self);
    next unless($neighbor->parent_link);
    next unless($neighbor->parent_link->equals($link));
    push @kids, $neighbor;
  }
  return \@kids;
}

=head2 sorted_children

  Overview   : returns a sorted list of NestedSet nodes directly under this parent node
               sort so that internal nodes<leaves and then on distance
  Example    : my @kids = @{$object->ordered_children()};
  Returntype : array reference of Bio::EnsEMBL::Compara::NestedSet objects (could be empty)
  Exceptions : none
  Caller     : general

=cut

sub sorted_children {
  my $self = shift;
  
  my @sortedkids = 
     sort { $a->is_leaf <=> $b->is_leaf     
                     ||
            $a->get_child_count <=> $b->get_child_count         
                     ||
            $a->distance_to_parent <=> $b->distance_to_parent
          }  @{$self->children;};
  return \@sortedkids;
}


=head2 get_all_nodes

  Arg 1       : hashref $node_hash [used for recursivity, do not use it!]
  Example     : my $all_nodes = $root->get_all_nodes();
  Description : Returns this and all underlying sub nodes
  ReturnType  : listref of Bio::EnsEMBL::Compara::NestedSet objects
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_nodes {
  my $self = shift;
  my $node_hash = shift;

  my $toplevel = 0;
  unless($node_hash) {
   $node_hash = {};
   $toplevel =1;
  }

  $node_hash->{$self->obj_id} = $self; 
  foreach my $child (@{$self->children}) {
    $child->get_all_nodes($node_hash);
  }

  if ($toplevel) {
    return [values(%$node_hash)];
  }
  return undef;
}


=head2 get_all_subnodes

  Arg 1       : hashref $node_hash [used for recursivity, do not use it!]
  Example     : my $all_nodes = $root->get_all_nodes();
  Description : Returns all underlying sub nodes
  ReturnType  : listref of Bio::EnsEMBL::Compara::NestedSet objects
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_subnodes {
  my $self = shift;
  my $node_hash = shift;
  
  my $toplevel = 0;
  unless($node_hash) {
   $node_hash = {};
   $toplevel =1;
  }

  foreach my $child (@{$self->children}) {
    $node_hash->{$child->obj_id} = $child; 
    $child->get_all_subnodes($node_hash);
  }
  return values(%$node_hash) if($toplevel);
  return undef;
}

=head2 get_all_ancestors

  Arg 1       : 
  Example     : my @ancestors = @{$node->get_all_ancestors};
  Description : Returns all ancestor nodes for a given node
  ReturnType  : listref of Bio::EnsEMBL::Compara::NestedSet objects
  Exceptions  : none
  Caller      : general
  Status      :

=cut

sub get_all_ancestors {
  my $self = shift;
  my $this = $self;
  my @ancestors;
  while( $this = $this->parent ){
    push @ancestors, $this;
  }
  return [@ancestors]
}

=head2 get_all_adjacent_subtrees

  Arg 1       : 
  Example     : my @subtrees = @{$node->get_all_adjacent_subtrees};
  Description : Returns subtree 'root' nodes where the subtree is adjacent
                to this node. Used e.g. by the web code for the 'collapse 
                other nodes' action 
  ReturnType  : listref of Bio::EnsEMBL::Compara::NestedSet objects
  Exceptions  : none
  Caller      : EnsEMBL::Web::Component::Gene::ComparaTree
  Status      :

=cut

sub get_all_adjacent_subtrees {
  my $self = shift;
  my $node_id = $self->node_id;
  my @node_path_to_root = ($self, @{$self->get_all_ancestors} );
  my %path_node_ids = map{ $_->node_id => 1 } @node_path_to_root;

  my $this = $self->subroot; # Start at the root node
  my @adjacent_subtrees;
  while( $this ){
    last if $this->node_id == $node_id; # Stop on reaching current node
    my $next;
    foreach my $child (@{$this->children}){
      warn( " => ", $child->node_id );
      next if $child->is_leaf; # Leaves cannot be subtrees
      if( $path_node_ids{$child->node_id} ){ # Ancestor node
        $next = $child;
      } else {
        push @adjacent_subtrees, $child;
      }
    }
    $this = $next || undef;
  }

  return [@adjacent_subtrees]
}


=head2 num_leaves

  Example     : my $num_leaves = $node->num_leaves
  Description : Returns the number of leaves underlying the node
  ReturnType  : integer
  Exceptions  : none
  Caller      : general
  Status      : At risk (relies on left and right indexes)

=cut
#'
sub num_leaves{
   my $self = shift;

   my $left = $self->left_index;
   my $right = $self->right_index;

   return undef unless (defined($left) && defined($right));

   my $num = $right - $left + 1;
   my $num_leaves = ( ($num/2) + 1 ) / 2;

   return $num_leaves;
}


sub get_child_count {
  my $self = shift;
  $self->load_children_if_needed;
  return scalar @{$self->children};
#  my $count = $self->link_count;
#  $count-- if($self->has_parent);
#  return $count;
}

sub load_children_if_needed {
  my $self = shift;
  if($self->adaptor and !defined($self->{'_children_loaded'})) {
    #define _children_id_hash thereby signally that I've tried to load my children
    $self->{'_children_loaded'} = 1; 
    #print("load_children_if_needed : "); $self->print_node;
    $self->adaptor->fetch_all_children_for_node($self);
  }
  return $self;
}

sub no_autoload_children {
  my $self = shift;
  
  return if($self->{'_children_loaded'});
  $self->{'_children_loaded'} = 1;
}


=head2 distance_to_parent

  Arg [1]    : (opt.) <int or double> distance
  Example    : my $dist = $object->distance_to_parent();
  Example    : $object->distance_to_parent(1.618);
  Description: Getter/Setter for the distance between this child and its parent
  Returntype : integer node_id
  Exceptions : none
  Caller     : general

=cut

sub distance_to_parent {
  my $self = shift;
  my $dist = shift;
  
  if($self->{'_parent_link'}) {
    if(defined($dist)) { $self->{'_parent_link'}->distance_between($dist); }
    else { $dist = $self->{'_parent_link'}->distance_between; }
  } else {
    if(defined($dist)) { $self->_distance($dist); }
    else { $dist = $self->_distance; } 
  }
  return $dist;
}

sub _distance  {
  my $self = shift;
  $self->{'_distance_to_parent'} = shift if(@_);
  $self->{'_distance_to_parent'} = 0.0 unless(defined($self->{'_distance_to_parent'}));
  return $self->{'_distance_to_parent'};
}

sub distance_to_root {
  my $self = shift;
  my $dist = $self->distance_to_parent;
  $dist += $self->parent->distance_to_root if($self->parent);
  return $dist;
}


=head2 distance_to_ancestor

  Arg [1]     : Bio::EnsEMBL::Compara::NestedSet $ancestor
  Example     : my $distance = $this_node->distance_to_ancestor($ancestor);
  Description : Calculates the distance in the tree between this node and
                its ancestor $ancestor
  Returntype  : float
  Exceptions  : throws if $ancestor is not an ancestor of this node.
  Caller      : general
  Status      : Stable

=cut

sub distance_to_ancestor {
  my $self = shift;
  my $ancestor = shift;

  if ($ancestor->node_id eq $self->node_id) {
    return 0;
  }
  unless (defined $self->parent) {
    throw("Ancestor not found\n");
  }
  return $self->distance_to_parent + $self->parent->distance_to_ancestor($ancestor);
}


=head2 distance_to_node

  Arg [1]     : Bio::EnsEMBL::Compara::NestedSet $node
  Example     : my $distance = $this_node->distance_to_node($other_node);
  Description : Calculates the distance in the tree between these
                two nodes.
  Returntype  : float
  Exceptions  : returns undef if no ancestor can be found, no distances are
                defined in the tree, etc.
  Caller      : general
  Status      : Stable

=cut

sub distance_to_node {
  my $self = shift;
  my $node = shift;

  my $ancestor = $self->find_first_shared_ancestor($node);
  if (!$ancestor) {
    return undef;
  }
  my $distance = $self->distance_to_ancestor($ancestor);
  $distance += $node->distance_to_ancestor($ancestor);

  return $distance;
}


=head2 print_tree

  Arg [1]     : int $scale
  Example     : $this_node->print_tree(100);
  Description : Prints this tree in ASCII format. The scale is used to define
                the width of the tree in the output
  Returntype  : undef
  Exceptions  :
  Caller      : general
  Status      : At risk (as the output might change)

=cut

sub print_tree {
  my $self  = shift;
  my $scale = shift;
  
  $scale = 100 unless($scale);
  $self->_internal_print_tree(undef, 0, $scale);
}


sub _internal_print_tree {
  my $self  = shift;
  my $indent = shift;
  my $lastone = shift;
  my $scale = shift; 

  if(defined($indent)) {
    print($indent);
    for(my $i=0; $i<$self->distance_to_parent()*$scale; $i++) { print('-'); }
  }
  
  $self->print_node($indent);

  if(defined($indent)) {
    if($lastone) {
      chop($indent);
      $indent .= " ";
    }
    for(my $i=0; $i<$self->distance_to_parent()*$scale; $i++) { $indent .= ' '; }
  }
  $indent = '' unless(defined($indent));
  $indent .= "|";

  my $children = $self->sorted_children;
  my $count=0;
  $lastone = 0;
  foreach my $child_node (@$children) {  
    $count++;
    $lastone = 1 if($count == scalar(@$children));
    $child_node->_internal_print_tree($indent,$lastone,$scale);
  }
}


sub print_node {
  my $self  = shift;

  print("(");
  if(defined $self->get_tagvalue("Duplication") 
     && $self->get_tagvalue("Duplication") ne '' 
     && $self->get_tagvalue("Duplication") > 0 
     && $self->get_tagvalue("dubious_duplication") ne '1') 
    {
      print("DUP ");
    } elsif (defined $self->get_tagvalue("Duplication") 
     && $self->get_tagvalue("Duplication") ne '' 
     && $self->get_tagvalue("Duplication") > 0 
     && $self->get_tagvalue("dubious_duplication") eq '1'
            ) 
    {
      print("DD  ");
    }
  if(defined $self->get_tagvalue("Bootstrap") && $self->get_tagvalue("Bootstrap") ne '') { my $bootstrap_value = $self->get_tagvalue("Bootstrap"); print("B=$bootstrap_value "); }
  if(defined $self->get_tagvalue("taxon_name") && $self->get_tagvalue("taxon_name") ne '') { my $taxon_name_value = $self->get_tagvalue("taxon_name"); print("T=$taxon_name_value "); }
  printf("%s %d,%d)", $self->node_id, $self->left_index, $self->right_index);
  printf("%s\n", $self->name);
}

sub nhx_format {
  my $self = shift;
  my $format_mode = shift;
  
  $format_mode="protein_id" unless(defined($format_mode));
  my $nhx = $self->_internal_nhx_format($format_mode); 
  $nhx .= ";";
  return $nhx;
}


sub _internal_nhx_format {
  my $self = shift;
  my $format_mode = shift;
  my $nhx = "";
  
  if($self->get_child_count() > 0) {
    $nhx .= "(";
    my $first_child=1;
    foreach my $child (@{$self->sorted_children}) {  
      $nhx .= "," unless($first_child);
      $nhx .= $child->_internal_nhx_format($format_mode);
      $first_child = 0;
    }
    $nhx .= ")";
  }
  
  if($format_mode eq "full" || $format_mode eq "display_label" || $format_mode eq "display_label_composite" || $format_mode eq "transcript_id" || $format_mode eq "gene_id" || $format_mode eq "protein_id") { 
      #full: name and distance on all nodes
      if($self->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
	  if ($format_mode eq "transcript_id") {
	      $self->description =~ /Transcript:(\w+)/;
	      my $transcript_stable_id = $1;
	      $nhx .= sprintf("%s", $transcript_stable_id);
	  } elsif ($format_mode eq "gene_id") {
            my $gene_stable_id = $self->gene_member->stable_id;
            $nhx .= sprintf("%s", $gene_stable_id);
	  } elsif ($format_mode eq "display_label_composite") {
            my $display_label = $self->gene_member->display_label;
            if (!defined($display_label) || $display_label eq '') {
              my $display_xref = $self->gene_member->gene->display_xref;
              $display_label = $display_xref->display_id if (defined($display_xref));
            }
            if (defined($display_label)) {
              $nhx .= $display_label . "_";
            }
            $nhx .= $self->gene_member->stable_id;
            $nhx .= "_" . $self->genome_db->short_name;
	  } elsif ($format_mode eq "display_label") {
            my $display_label = $self->gene_member->display_label;
            if (!defined($display_label) || $display_label eq '') {
              my $display_xref = $self->gene_member->gene->display_xref;
              $display_label = $display_xref->display_id if (defined($display_xref));
            }
            if (defined($display_label) && $display_label =~ /^\w+$/) {
              $nhx .= $display_label . "_";
            } else {
              $nhx .= $self->gene_member->stable_id . "_";
            }
            # $nhx .= $self->gene_member->stable_id;
            $nhx .= $self->genome_db->short_name;
	  } elsif ($format_mode eq "protein_id") {
            $nhx .= sprintf("%s", $self->name);
          }
      } else {
        my $name = sprintf("%s", $self->name);
        $name = sprintf("%s", $self->get_tagvalue("taxon_name")) if ($name eq '');
        $nhx .= $name;
      }
    $nhx .= sprintf(":%1.4f", $self->distance_to_parent);
    $nhx .= "[&&NHX";
    if(defined $self->get_tagvalue("Duplication") && $self->get_tagvalue("Duplication") ne '' && $self->get_tagvalue("Duplication") > 0) { 
        # mark as duplication
        $nhx .= ":D=Y";
    } else {
        # this only applies to internal nodes, hence the name of the
        # method and the reason we can safely add this here
        $nhx .= ":D=N";
    }
    if(defined $self->get_tagvalue("Bootstrap") && $self->get_tagvalue("Bootstrap") ne '') { 
      my $bootstrap_value = $self->get_tagvalue("Bootstrap");
        # mark as duplication
        $nhx .= ":B=$bootstrap_value";
    }
    my $taxon_id;
    if($self->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
      my $gene_stable_id = $self->gene_member->stable_id;
      if (defined $gene_stable_id && $format_mode eq "transcript_id") {
        $nhx .= ":G=$gene_stable_id";
      } elsif (defined $gene_stable_id && $format_mode eq "gene_id") {
        $self->description =~ /Transcript:(\w+)/;
        my $transcript_stable_id = $1;
        $nhx .= ":G=$transcript_stable_id";
      } elsif (defined $gene_stable_id && $format_mode eq "protein_id") {
        $nhx .= ":G=$gene_stable_id";
      }
      $taxon_id = $self->taxon_id;
    } else {
      $taxon_id = $self->get_tagvalue("taxon_id");
    }
    if(defined ($taxon_id) && (!($taxon_id eq ''))) {
	$nhx .= ":T=$taxon_id";
    }
    $nhx .= "]";
  }
  if($format_mode eq 'simple') { 
    #simplified: name only on leaves, dist only if has parent
    if($self->parent) {
      if($self->is_leaf) {
        $nhx .= sprintf("%s", $self->name);
      }
      $nhx .= sprintf(":%1.4f", $self->distance_to_parent);
    }
  }
  if($format_mode eq 'phylip') { 
    #phylip: restrict names to 21 characters
    if($self->parent) {
      if($self->is_leaf) {
        my $name = $self->name;
        $name =~ s/[,(:)]//g;
        $name = substr($name, 0 , 21);
        $nhx .= sprintf("%s", $name);
      }
      $nhx .= sprintf(":%1.4f", $self->distance_to_parent);
    }
  }

  return $nhx;
}


=head2 newick_format

  Arg [1]     : string $format_mode
  Example     : $this_node->newick_format("full");
  Description : Prints this tree in Newick format. Several modes are
                available: full, display_label_composite, simple, species,
                species_short_name, ncbi_taxon, ncbi_name, njtree and phylip
  Returntype  : undef
  Exceptions  :
  Caller      : general
  Status      : Stable

=cut

sub newick_format {
  my $self = shift;
  my $format_mode = shift;
  
  $format_mode="full" unless(defined($format_mode));
  my $newick = $self->_internal_newick_format($format_mode); 
  $newick .= ";";
  return $newick;
}


sub _internal_newick_format {
  my $self = shift;
  my $format_mode = shift;
  my $newick = "";
  
  if($self->get_child_count() > 0) {
    $newick .= "(";
    my $first_child=1;
    foreach my $child (@{$self->sorted_children}) {  
      $newick .= "," unless($first_child);
      $newick .= $child->_internal_newick_format($format_mode);
      $first_child = 0;
    }
    $newick .= ")";
  }
  
  if($format_mode eq "full") { 
    #full: name and distance on all nodes
    $newick .= sprintf("%s", $self->name);
    $newick .= sprintf(":%1.4f", $self->distance_to_parent);
  }
  if($format_mode eq "full_common") { 
    #full: name and distance on all nodes
    my $name = $self->name;
    my $full_common_name = $name;
    if ($self->is_leaf) {
      my $common = uc($self->get_tagvalue('genbank common name'));
      $common = uc($self->get_tagvalue('ensembl common name')) if (1 > length($common));
      $common =~ s/\,//g;
      $common =~ s/\ /\./g;
      $common =~ s/\'//g;
      $full_common_name .= " " . $common if (1 < length($common));
    }
    $newick .= sprintf("%s", $full_common_name);
    $newick .= sprintf(":%1.4f", $self->distance_to_parent);
  }
  if($format_mode eq "int_node_id") { 
    #full: name and distance on all nodes
    $newick .= sprintf("%s", $self->name) if ($self->is_leaf);
    $newick .= sprintf("%s", $self->node_id) if (!$self->is_leaf);
    $newick .= sprintf(":%1.4f", $self->distance_to_parent);
  }
  if($format_mode eq "display_label_composite") { 
    #display_label: external name and distance on all nodes
    my $display_label;
    if($self->is_leaf) {
      $display_label = $self->gene_member->display_label;
    }
    if (defined($display_label)) {
      $newick .= $display_label . "_";
    }
    $newick .= $self->name;
    if ($self->is_leaf) {
      $newick .= "_" . $self->genome_db->short_name;
    }
    $newick .= sprintf(":%1.4f", $self->distance_to_parent);
  }
  if($format_mode eq "full_web") { 
    #display_label: external name and distance on all nodes
    my $display_label;
    if($self->is_leaf) {
      my $gene_member = $self->gene_member;
      my $short_name = $gene_member->genome_db->short_name;
      $display_label = $gene_member->display_label || $gene_member->stable_id;
      $display_label = $short_name . ":" . $display_label;
    }
    # $newick .= $self->name;
    $newick .= sprintf(":%1.4f", $self->distance_to_parent);
  }
  if($format_mode eq "gene_stable_id") { 
    #display_label: external name and distance on all nodes
    my $display_label;
    if($self->is_leaf) {
      $display_label = $self->gene_member->stable_id;
    }
    if (defined($display_label)) {
      $newick .= $display_label;
    }
    $newick .= sprintf(":%1.4f", $self->distance_to_parent);
  }
  if($format_mode eq "otu_id") { 
    #out_id: species name then "|" then external name
    my $display_label;
    if($self->is_leaf) {
      $display_label = $self->gene_member->display_label;
    }
    if ($self->is_leaf) {
      $newick .= $self->genome_db->short_name . "|";
    }
    if (defined($display_label)) {
      $newick .= $display_label;
    }
    $newick .= $self->name;
    $newick .= sprintf(":%1.4f", $self->distance_to_parent);
  }
  if($format_mode eq 'simple') { 
    #simplified: name only on leaves, dist only if has parent
    if($self->parent) {
      if($self->is_leaf) {
        $newick .= sprintf("%s", $self->name);
      }
      $newick .= sprintf(":%1.4f", $self->distance_to_parent);
    }
  }
  if($format_mode eq 'species') { 
    #simplified: name only on leaves, dist only if has parent
    if($self->parent) {
      if($self->is_leaf) {
        my $species_name;
        if ($self->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
          $species_name = $self->genome_db->name;
        } else {
          $species_name = $self->name;
        }
        $species_name =~ s/\ /\_/g;
        $newick .= sprintf("%s", $species_name);
      }
    }
  }
  if($format_mode eq 'species_short_name') { 
    #simplified: name only on leaves, dist only if has parent
    if($self->parent) {
      if($self->is_leaf) {
        my $species_name;
        if ($self->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
          $species_name = $self->genome_db->short_name;
        } else {
          $species_name = $self->short_name;
        }
        $newick .= sprintf("%s", $species_name);
      }
    }
  }
  if($format_mode eq 'ncbi_taxon') { 
    #name leaves an internal nodes by ncbi taxon_id
    if($self->parent) {
      my $ncbi_taxon_id = $self->node_id;
      $newick .= sprintf("%s", $ncbi_taxon_id);
    }
  }
  if($format_mode eq 'ncbi_name') { 
    #name leaves an internal nodes by ncbi taxon_id
    if($self->parent) {
      my $ncbi_name = $self->name;
      $newick .= sprintf("%s", $ncbi_name);
    }
  }
  if($format_mode eq 'njtree') { 
    #name leaves an internal nodes by ncbi taxon_id
    #add * for leaves
      my $ncbi_taxon_id = $self->node_id;
      if($self->is_leaf) { 
        my $is_incomplete = $self->get_tagvalue("is_incomplete");
        $ncbi_taxon_id .= "*" unless ('1' eq $is_incomplete);
      }
      $newick .= sprintf("%s", $ncbi_taxon_id);
  }
  if($format_mode eq 'phylip') { 
    #phylip: restrict names to 21 characters
    if($self->parent) {
      if($self->is_leaf) {
        my $name = $self->name;
        $name =~ s/[,(:)]//g;
        $name = substr($name, 0 , 21);
        $newick .= sprintf("%s", $name);
      }
      $newick .= sprintf(":%1.4f", $self->distance_to_parent);
    }
  }

  return $newick;
}


=head2 newick_simple_format

  Arg [1]     : -none-
  Example     : $this_node->newick_simple_format();
  Description : Prints this tree in simple Newick format. This is an
                alias for $this_node->newick_format("simple");
  Returntype  : undef
  Exceptions  :
  Caller      : general
  Status      : Stable

=cut

sub newick_simple_format {
  my $self = shift;
  return $self->newick_format('simple'); 
}


##################################
#
# Set theory methods
#
##################################

#sub equals {
#  my $self = shift;
#  my $other = shift;
#  throw("arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a [$other]")
#        unless($other->isa('Bio::EnsEMBL::Compara::NestedSet'));
#  return 1 if($self->node_id eq $other->node_id);
#  foreach my $child (@{$self->children}) {
#    return 0 unless($other->has_child($child));
#  }
#  return 1;
#}

sub has_child {
  my $self = shift;
  my $child = shift;
  throw("arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a [$child]")
        unless($child->isa('Bio::EnsEMBL::Compara::NestedSet'));
  $self->load_children_if_needed;
  my $link = $self->link_for_neighbor($child);
  return 0 unless($link);
  return 0 if($self->{'_parent_link'} and ($self->{'_parent_link'}->equals($link)));
  return 1;
}

sub is_member_of {
  my $A = shift;
  my $B = shift;
  return 1 if($B->has_child($A));
  return 0; 
}

sub is_subset_of {
  my $A = shift;
  my $B = shift;
  foreach my $child (@{$A->children}) {
    return 0 unless($B->has_child($child));
  }
  return 1; 
}

sub is_leaf {
  my $self = shift;
  return 1 unless($self->get_child_count);
  return 0;
}

sub merge_children {
  my $self = shift;
  my $nset = shift;
  throw("arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a [$nset]")
        unless($nset->isa('Bio::EnsEMBL::Compara::NestedSet'));
  foreach my $child_node (@{$nset->children}) {
    $self->add_child($child_node, $child_node->distance_to_parent);
  }
  return $self;
}

sub merge_node_via_shared_ancestor {
  my $self = shift;
  my $node = shift;

  my $node_dup = $self->find_node_by_node_id($node->node_id);
  if($node_dup) {
    #warn("trying to merge in a node with already exists\n");
    return $node_dup;
  }
  return undef unless($node->parent);
  
  my $ancestor = $self->find_node_by_node_id($node->parent->node_id);
  if($ancestor) {
    $ancestor->add_child($node);
    #print("common ancestor at : "); $ancestor->print_node;
    return $ancestor;
  }
  return $self->merge_node_via_shared_ancestor($node->parent);
}

##################################
#
# nested_set manipulations
#
##################################

sub flatten_tree {
  my $self = shift;
  
  my $leaves = $self->get_all_leaves;
  foreach my $leaf (@{$leaves}) { 
    $leaf->disavow_parent;
  }

  $self->release_children;
  foreach my $leaf (@{$leaves}) {
    $self->add_child($leaf, 0.0);
  }
  
  return $self;
}

=head2 re_root

  Overview   : rearranges the tree structure so that the root is moved to 
               beetween this node and its parent.  If the old root was more than
	       bifurcated (2 children) a new node is created where it was to hold
	       the multiple children that arises from the re-rooting.  
	       The old root is returned.
  Example    : $node->re_root();
  Returntype : undef or Bio::EnsEMBL::Compara::NestedSet
  Exceptions : none
  Caller     : general

=cut

sub re_root {
  my $self = shift;
  
  return $self unless($self->parent); #I'm root so just return self

  my $root = $self->root;
  my $tmp_root = new Bio::EnsEMBL::Compara::NestedSet;
  $tmp_root->merge_children($root);
    
  my $parent = $self->parent;
  my $dist = $self->distance_to_parent;
  $self->disavow_parent;

  my $old_root = $parent->_invert_tree_above;
  $old_root->minimize_node;
  
  $root->add_child($parent, $dist / 2.0);
  $root->add_child($self, $dist / 2.0);
  
  return $root;
}


sub _invert_tree_above {
  my $self = shift;
  return $self unless($self->parent);
  
  my $old_root =  $self->parent->_invert_tree_above;
  #now my parent has been inverted so it is the new root
  
  #flip the direction of the link between myself and my parent
  $self->parent->_set_parent_link($self->{'_parent_link'});
  $self->_set_parent_link(undef);
  
  #now I'm the new root and the old root might need to be modified
  return $old_root;
}


sub build_leftright_indexing {
  my $self = shift;
  my $counter = shift;
  
  $counter = 1 unless($counter);
  
  $self->left_index($counter++);
  foreach my $child_node (@{$self->sorted_children}) {
    $counter = $child_node->build_leftright_indexing($counter);
  }
  $self->right_index($counter++);
  return $counter;
}


=head2 remove_nodes

  Arg [1]     : arrayref Bio::EnsEMBL::Compara::NestedSet $nodes
  Example     : my $ret_tree = $tree->remove_nodes($nodes);
  Description : Returns the tree with removed nodes in list. Nodes should be in the tree.
  Returntype  : Bio::EnsEMBL::Compara::NestedSet object
  Exceptions  :
  Caller      : general
  Status      : At risk (behaviour on exceptions could change)

=cut

sub remove_nodes {
  my $self = shift;
  my $nodes = shift;

  foreach my $node (@$nodes) {
    if ($node->is_leaf) {
      $node->disavow_parent;
      $self = $self->minimize_tree;
    } else {
      my $node_children = $node->children;
      foreach my $child (@$node_children) {
        $node->parent->add_child($child);
      }
      $node->disavow_parent;
    }
    # Delete dangling one-child trees (help memory manager)
    if ($self->get_child_count == 1) {
      my $child = $self->children->[0];
      $child->parent->merge_children($child);
      $child->disavow_parent;
      return undef;
    }
    # Could be zero if all asked to delete, so return undef instead of
    # fake one-node tree.
    if ($self->get_child_count < 2) {
      return undef;
    }
  }
  return $self;
}


=head2 minimize_tree

  Arg [1]     : -none-
  Example     : $leaf->disavow_parent();
                $tree = $tree->minimize_tree();
  Description : Returns the tree after removing internal nodes that do not
                represent an multi- or bi-furcation anymore. This is typically
                required after disavowing a node. Please ensure you use the
                object returned by the method and not the original object
                anymore!
  Returntype  : Bio::EnsEMBL::Compara::NestedSet object
  Exceptions  :
  Caller      : general
  Status      : Stable

=cut

sub minimize_tree {
  my $self = shift;
  return $self if($self->is_leaf);
  
  foreach my $child (@{$self->children}) { 
    $child->minimize_tree;
  }
  return $self->minimize_node;
}


sub minimize_node {
  my $self = shift;
  
  return $self unless($self->get_child_count() == 1);
  
  my $child = $self->children->[0];
  my $dist = $child->distance_to_parent + $self->distance_to_parent;
  if ($self->parent) {
     $self->parent->add_child($child, $dist); 
     $self->disavow_parent;
  } else {
     $child->disavow_parent;
  }
  return $child
}



##################################
#
# search methods
#
##################################

sub find_node_by_name {
  my $self = shift;
  my $name = shift;
  
  return $self if($name eq $self->name);
  
  my $children = $self->children;
  foreach my $child_node (@$children) {
    my $found = $child_node->find_node_by_name($name);
    return $found if(defined($found));
  }
  
  return undef;
}

sub find_node_by_node_id {
  my $self = shift;
  my $node_id = shift;
  
  return $self if($node_id eq $self->node_id);
  
  my $children = $self->children;
  foreach my $child_node (@$children) {
    my $found = $child_node->find_node_by_node_id($node_id);
    return $found if(defined($found));
  }
  
  return undef;
}

sub find_leaf_by_name {
  my $self = shift;
  my $name = shift;

  return $self if($name eq $self->name);

  my $leaves = $self->get_all_leaves;
  foreach my $leaf (@$leaves) {
    return $leaf if($name eq $leaf->name);
  }

  return undef;
}

sub find_leaf_by_node_id {
  my $self = shift;
  my $node_id = shift;

  return $self if($node_id eq $self->node_id);

  my $leaves = $self->get_all_leaves;
  foreach my $leaf (@$leaves) {
    return $leaf if($node_id eq $leaf->node_id);
  }

  return undef;
}


=head2 get_all_leaves

 Title   : get_all_leaves
 Usage   : my @leaves = @{$tree->get_all_leaves};
 Function: searching from the given starting node, searches and creates list
           of all leaves in this subtree and returns by reference
 Example :
 Returns : reference to list of NestedSet objects (all leaves)
 Args    : none

=cut

sub get_all_leaves {
  my $self = shift;
  
  my $leaves = {};
  $self->_recursive_get_all_leaves($leaves);
  my @leaf_list = sort {$a->node_id <=> $b->node_id} values(%{$leaves});
  return \@leaf_list;
}

sub _recursive_get_all_leaves {
  my $self = shift;
  my $leaves = shift;
    
  $leaves->{$self->obj_id} = $self if($self->is_leaf);

  foreach my $child (@{$self->children}) {
    $child->_recursive_get_all_leaves($leaves);
  }
  return undef;
}


sub get_all_leaves_indexed {
  my $self = shift;

  my @leaf_list = @{$self->adaptor->fetch_all_leaves_indexed($self)};

  return \@leaf_list;
}

=head2 max_distance

 Title   : max_distance
 Args    : none
 Usage   : $tree_node->max_distance;
 Function: searching from the given starting node, calculates the maximum distance to a leaf
 Returns : int

=cut

sub max_distance {
  my $self = shift;

  my $max_distance = 0;
  
  foreach my $child (@{$self->children}) {
    my $distance = $child->max_distance;
    $max_distance = $distance if($distance>$max_distance);
  }

  return ($self->distance_to_parent + $max_distance);
}


=head2 max_depth

 Title   : max_depth
 Args    : none
 Usage   : $tree_node->max_depth;
 Function: searching from the given starting node, calculates the maximum depth to a leaf
 Returns : int

=cut

sub max_depth {
  my $self = shift;

  my $max_depth = 0;
  
  foreach my $child (@{$self->children}) {
    my $depth = $child->max_depth + 1;
    $max_depth=$depth if($depth>$max_depth);
  }
  return $max_depth;  
}


=head2 find_first_shared_ancestor

  Arg [1]     : Bio::EnsEMBL::Compara::NestedSet $node
  Example     : my $ancestor = $this_node->find_first_shared_ancestor($other_node);
  Description : Gets the first common ancestor between this node and the other one.
  Returntype  : Bio::EnsEMBL::Compara::NestedSet object
  Exceptions  :
  Caller      : general
  Status      : Stable

=cut

sub find_first_shared_ancestor {
  my $self = shift;
  my $node = shift;

  return $self if($self->equals($node));
  return $node if($self->has_ancestor($node));  
  return $self->find_first_shared_ancestor($node->parent);
}


##################################
#
# developer/adaptor API methods
#
##################################


# used for building tree from a DB fetch, want to restrict users to create trees
# by only -add_child method
sub _set_parent_link {
  my ($self, $link) = @_;
  
  $self->{'_parent_id'} = 0;
  $self->{'_parent_link'} = $link;
  $self->{'_parent_id'} = $link->get_neighbor($self)->node_id if($link);
  return $self;
}


# used for building tree from a DB fetch until all the objects are in memory
sub _parent_id {
  my $self = shift;
  $self->{'_parent_id'} = shift if(@_);
  return $self->{'_parent_id'};
}

# used for building tree from a DB fetch until all the objects are in memory
sub _root_id {
  my $self = shift;
  $self->{'_root_id'} = shift if(@_);
  return $self->{'_root_id'};
}

1;

