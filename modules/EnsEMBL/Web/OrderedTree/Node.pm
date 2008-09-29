package EnsEMBL::Web::OrderedTree::Node;

use strict;

sub new {
  my( $class, $data ) = @_;
  my $self = $data;
  bless $self, $class;
  return $self;
}

sub key {
  return $_[0]{_key};
}
sub _tree_info {
### Handle on the tree info hash....
  return $_[0]{_tree_info};
}

sub _nodes {
### Return reference to nodes....
  return $_[0]{_tree_info}{nodes};
}

sub _node {
### Return the current node hash...
  my $self = shift;
  my $key = shift || $self->{_key}; 
  return $self->_nodes->{$key};
}

sub user_data {
  my $self = shift;
  return $self->{_user_data};
}

sub leaves {
  my $self = shift;
  my $l1 = $self->left;
  my $r1 = $self->right;
  return map { $self->get_node( $_ ) } grep { my $T = $self->_node($_); $T->{left} >= $l1 && $T->{left} < $r1 && $T->{right} == $T->{left}+1 } $self->_sorted_keys;
}

sub nodes {
### Returns list of all nodes in and under this node!
  my $self = shift;
  my $l1 = $self->left;
  my $r1 = $self->right;
  return map { $self->_node($_)->{left} >= $l1 && $self->_node($_)->{left} < $r1 ? $self->get_node( $_ ) : () } $self->_sorted_keys;
}

sub descendants {
### Returns list of all nodes under this node!
  my $self = shift;
  my $l1 = $self->left;
  my $r1 = $self->right;
  return map { $self->_node($_)->{left} > $l1 && $self->_node($_)->{left} < $r1 ? $self->get_node( $_ ) : () } $self->_sorted_keys;
}
sub left        { $_[0]->_node->{left};                }
sub right       { $_[0]->_node->{right};               }
sub data        { $_[0]->_node->{data};                }

sub get         { 
### a
### Returns user value if defined - otherwise returns value from data...
  my $self = shift;
  my $k    = shift;
  my $v= exists $self->{_user_data} &&
         exists $self->{_user_data}{$self->{_key}} &&
         exists $self->{_user_data}{$self->{_key}}{$k} ?  $self->{_user_data}{$self->{_key}}{$k} :
	                                                  $self->data->{$k};
  return $v;
}

sub set         {
  my $self = shift;
  my $k    = shift;
  my $v    = shift;
  $self->_node->{data}{$k} = $v;
}

sub set_user    {
# Set user data for node...
  my $self = shift;
  my $k    = shift;
  my $v    = shift;
## If same as default value - flush node!!
  return $self->flush_user( $k ) if $v eq $self->data->{$k};
## If not same as current value set and return true!
  if( $v ne $self->{_user_data}{$self->{_key}}{$k} ) {
    $self->{_user_data}{$self->{_key}}{$k} = $v;
    return 1; 
  }
  return 0; ## Return false - not updated!!
}

sub flush_user {
  my $self = shift;
  my $k    = shift;
  if( defined $k ) {
### Remove a particular user setting for this node...
    if( exists $self->{_user_data}{$self->{_key}} && exists $self->{_user_data}{$self->{_key}}{$k} ) {
      ## Only do the delete if the key exists...
      delete $self->{_user_data}{$self->{_key}}{$k};
      unless( keys %{ $self->{_user_data}{$self->{_key}}} ) {
        ## Delete configuration for user if there are no keys left!!
        delete $self->{_user_data}{$self->{_key}};
      }
      return 1;
    }
  } else {
### Remove all user settings for this node...
    if( exists( $self->{_user_data}{$self->{_key}} ) ) {
      ## Only delete if entry exists in tree!!
      delete $self->{_user_data}{$self->{_key}};
      return 1;
    }
  }
  return 0; ## Not updated!!
}

sub parent_key  { $_[0]->_node->{parent_key};          }

sub _sorted_keys {
  my $self = shift;
  my @sorted_keys = @{$self->{_tree_info}{_sorted_keys}};
  unless( @sorted_keys ) {
    @sorted_keys = 
      sort { $self->_node($a)->{'left'} <=> $self->_node($b)->{'left'} }
      keys %{$self->_nodes};
    $self->{_tree_info}{_sorted_keys} = \@sorted_keys;
  }
  return @sorted_keys;
}

sub is_leaf {
  my( $self ) = @_;
  return $self->right == $self->left + 1;
}

sub is_ancestor_of {
### Return true if this node is ancestor of $node;
  my( $self, $node ) = @_;
  return $node->left <= $node->left && $node->right <= $self->right;
}

sub is_descendant_of {
### Return true if this node is descendant of $node;
  my( $self, $node ) = @_;
  return $node->left <= $self->left && $self->right <= $node->right;
}

sub is_parent_of {
### Return true if this node is direct ancestor of $node;
  my( $self, $node ) = @_;
  return $self->key eq $node->parent_key;
}

sub is_child_of {
### Return true if this node is direct descendant of $node;
  my( $self, $node ) = @_;
  return $self->parent_key eq $node->key;
}



sub remove_node {
### Remove a node - only if is a leaf node!!
  my( $self ) = @_;
  return $self->remove_subtree if $self->right = $self->left+1;
}

sub remove_subtree {
### Remove subtree even if it is not empty!!
  my( $self ) = @_;
  my $l1 = $self->left;
  my $r1 = $self->right;
  my $off = $r1-$l1+1;
  foreach my $k ( keys %{$self->_nodes} ) {
    my $l = $self->_node($k)->{left};
    my $r = $self->_node($k)->{right};
    if( $l >= $l1 && $l < $r1 ) {
      delete( $self->_nodes->{$k} );
    } elsif( $r >= $r1 ) {
      $self->_node($k)->{left}  -= $off if $l > $r1;
      $self->_node($k)->{right} -= $off;
    }
  }
  $self->{_tree_info}{_sorted_keys} = []; 
}

sub get_node {
  my $self = shift;
  my $key  = shift;
  
  return
    exists( $self->_nodes->{$key} ) ?
    EnsEMBL::Web::OrderedTree::Node->new( { '_key' => $key, '_tree_info' => $self->{_tree_info}, '_user_data' => $self->{_user_data} } ) :
    undef;
}

sub previous {
### Get the previous leaf node - irrespective of the subtree it is in
### Returns node object - or undef if current node is first leaf....
  my( $self ) = @_;
  my $l1 = $self->left;
  my @Q = $self->_sorted_keys;
  my $previous = undef;
  foreach(@Q) {
    my $n = $self->_node($_);
    last if $n->{left} == $l1;
    $previous = $_;
  }
  return $previous ? $self->get_node( $previous ) : undef;
}

sub next {
### Get the next leaf node - irrespective of the subtree it is in
### Returns node object - or undef if current node is last leaf....
  my( $self ) = @_;
  my $l1 = $self->left;
  my @Q = reverse $self->_sorted_keys;
  my $next = undef;
  foreach(@Q) {
    my $n = $self->_node($_);
    last if $n->{left} == $l1;
    $next = $_;
  }
  return $next ? $self->get_node( $next ) : undef;
}

sub previous_leaf {
### Get the previous leaf node - irrespective of the subtree it is in
### Returns node object - or undef if current node is first leaf....
  my( $self ) = @_;
  my $l1 = $self->left;
  my @Q = $self->_sorted_keys;
  my $previous = undef;
  foreach(@Q) {
    my $n = $self->_node($_);
    last if $n->{left} == $l1;
    $previous = $_ if $n->{right} == $n->{left}+1;
  }
  return $previous ? $self->get_node( $previous ) : undef;
}

sub next_leaf {
### Get the next leaf node - irrespective of the subtree it is in
### Returns node object - or undef if current node is last leaf....
  my( $self ) = @_;
  my $l1 = $self->left;
  my @Q = reverse $self->_sorted_keys;
  my $next = undef;
  foreach(@Q) {
    my $n = $self->_node($_);
    last if $n->{left} == $l1;
    $next = $_ if $n->{right} == $n->{left}+1;
  }
  return $next ? $self->get_node( $next ) : undef;
}

sub _reorder_nodes {
### private function ... move subtree [$l1,$r1] to [$l0,..] used by
### add_before; add_after

  my( $self, $l1,$r1, $l0 ) = @_;
  return if $l1 == $l0; #do nothing if not moving!!
  if( $l0 < $l1 ) {
    foreach my $k ( keys %{$self->_nodes} ) {
      my $l = $self->_node($k)->{left};
      my $r = $self->_node($k)->{right};
      next if $r < $l0;
      next if $l > $r1;
      if( $l >= $l1 && $l <= $r1 ) {
        $self->_node($k)->{left}  += $l0 - $l1;
        $self->_node($k)->{right} += $l0 - $l1;
      } else {
        $self->_node($k)->{left}   += $r1 - $l1 + 1 if $l >= $l0 && $l < $l1;
        $self->_node($k)->{right}  += $r1 - $l1 + 1 if $r >= $l0 && $r < $l1;
      }
    }
  } elsif( $l1 < $l0 ) {
    foreach my $k ( keys %{$self->_nodes} ) {
      my $l = $self->_node($k)->{left};
      my $r = $self->_node($k)->{right};
      next if $r < $l1;
      next if $l > $l0;
      if( $l >= $l1 && $l <= $r1 ) {
        $self->_node($k)->{left}  += $l0 - $r1 -1 ;
        $self->_node($k)->{right} += $l0 - $r1 -1;
      } else {
        $self->_node($k)->{left}  -= ($r1 - $l1 + 1 ) if $l > $r1 && $l < $l0;
        $self->_node($k)->{right} -= ($r1 - $l1 + 1 ) if $r > $r1 && $r < $l0;
      }
    }
  }
  $self->{_tree_info}{_sorted_keys} = [];
}

sub add_before {
### Splice in subtree $node as sibling before current node!
  my( $self, $node ) = @_;
  return undef if $self->is_descendant_of( $node ); # Cannot splice tree as part of parent
  $node->_node()->{parent_key} = $self->parent_key;
  $self->_reorder_nodes( $node->left, $node->right, $self->left );
  return 1;
}

sub add_after {
### Splice in subtree $node as sibling before current node!
  my( $self, $node ) = @_;
  return undef if $self->is_descendant_of( $node ); # Cannot splice tree as part of parent
  $node->_node()->{parent_key} = $self->parent_key;
  warn join ' - ',  $node->left,$node->right, $self->right+1;
  $self->_reorder_nodes( $node->left, $node->right, $self->right+1 );
  return 1;
}

sub append {
### Splice in subtree $node as last child of current node!
  my( $self, $node ) = @_;
  return undef if $self->is_descendant_of( $node ); # Cannot splice tree as part of parent
  $node->_node()->{parent_key} = $self->key;
  $self->_reorder_nodes( $node->left, $node->right, $self->right );
  return 1;
}

sub prepend {
### Splice in subtree $node as last child of current node!
  my( $self, $node ) = @_;
  return undef if $self->is_descendant_of( $node ); # Cannot splice tree as part of parent
  $node->_node()->{parent_key} = $self->key;
  $self->_reorder_nodes( $node->left, $node->right, $self->left + 1 );
  return 1;
}

1;

