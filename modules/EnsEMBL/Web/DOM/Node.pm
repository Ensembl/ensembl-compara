package EnsEMBL::Web::DOM::Node;

use strict;

use HTML::Entities qw(encode_entities decode_entities);
use Clone qw(clone);
use Data::Dumper;

use EnsEMBL::Web::DOM;
use EnsEMBL::Web::Tools::RandomString;

use constant {
  ELEMENT_NODE                 => 1,
  TEXT_NODE                    => 3,
  COMMENT_NODE                 => 8,
  DOCUMENT_NODE                => 9,
};

sub new {
  ## @constructor
  ## @param DOM object 
  my ($class, $dom) = @_;
  return bless {
    '_attributes'           => {},
    '_child_nodes'          => [],
    '_text'                 => '',
    '_dom'                  => $dom || new EnsEMBL::Web::DOM, #creates new DOM object if not provided as arg
    '_parent_node'          => 0,
    '_next_sibling'         => 0,
    '_previous_sibling'     => 0,
    '_flags'                => {},
  }, $class;
}

sub set_flag {
  ## Sets/modifies a flag
  ## @param flag name
  ## @param flag value (optional - takes 1 as default)
  ## @return flag value
  my $self = shift;
  my $flag = shift;
  return $self->{'_flags'}{$flag} = scalar @_ ? shift : 1;
}

sub get_flag {
  ## Gets previously set flag
  ## @param flag name
  ## @return flag value if set or undef if not
  my ($self, $flag) = @_;
  return exists $self->{'_flags'}{$flag} ? $self->{'_flags'}{$flag} : undef;
}

sub reset_flags {
  ## Removes all the flags set
  shift->{'_flags'} = {};
}

sub can_have_child {
  ## Tells whether this node can have child nodes
  ## Override in child class
  ## @return 1 or 0 accordingly
  return 1;
}

sub node_type {
  ## Returns Node type as described in constants
  ## Override in child class
  ## @return Node type in integers
  return 0;
}

sub node_name {
  ## Returns Node name
  ## Override in child class
  ## @return  HTML tag name in case of Element node type, blank string otherwise
  return '';
}

sub render {
  ## Outputs the node html
  ## Override in child class
  ## @return output HTML
  return '';
}

sub get_all_nodes {
  ## Gets all the child nodes recursively from a node
  ## @return ArrayRef of Node objects
  my $self  = shift;
  my $nodes = [];
  
  push @$nodes, $self if @_ && shift;
  push @$nodes, @{$_->get_all_nodes(1)} for @{$self->child_nodes};
  return $nodes;
}

sub get_nodes_by_node_type {
  ## Gets all the child nodes (recursively) with a particular node type
  ## @param Node type (as in constants)
  ## @return ArrayRef of Node objects
  my $self      = shift;
  my $node_type = shift;
  my $nodes     = [];

  push @$nodes, $self if $self->node_type == $node_type && @_ && shift;
  push @$nodes, @{$_->get_nodes_by_node_type($node_type, 1)} for @{$self->child_nodes};
  return $nodes;
}

sub get_element_by_id {
  ## Typical getElementById
  ## @param Element id
  ## @return Element object
  my ($self, $id) = @_;

  #works for document and element only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE) {
    for (@{$self->child_nodes}) {
      next unless $_->node_type == $self->ELEMENT_NODE;
      return $_ if $_->id eq $id;
      my $child_with_this_id = $_->get_element_by_id($id);
      return $child_with_this_id if defined $child_with_this_id;
    }
  }
  return undef;
}

sub get_elements_by_name {
  ## A slight extension of typical getElementsByName
  ## @param name or ArrayRef of multiple names
  ## @return ArrayRef of Element objects
  my ($self, $name) = @_;
  
  $name         = [ $name ] unless ref($name) eq 'ARRAY';
  my $name_hash = { map {$_ => 1} @{$name} };
  my $result    = [];

  #works for document or element only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE) {
    for (@{$self->child_nodes}) {
      next unless $_->node_type == $self->ELEMENT_NODE;
      push @$result, $_ if $name_hash->{$_->name};
      push @$result, @{$_->get_elements_by_name($name)};
    }
  }
  return $result;
}

sub get_elements_by_tag_name {
  ## A slight extension of typical getElementsByTagName
  ## @param Tag name (string) or ArrayRef of multiple tag names
  ## @return ArrayRef of Element objects
  my ($self, $tag_name) = @_;
  
  $tag_name     = [ $tag_name ] unless ref($tag_name) eq 'ARRAY';
  my $tag_hash  = { map {$_ => 1} @{$tag_name} };
  my $result    = [];

  #works for document or element only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE) {
    for (@{$self->child_nodes}) {
      next unless $_->node_type == $self->ELEMENT_NODE;
      push @$result, $_ if $tag_hash->{$_->node_name};
      push @$result, @{$_->get_elements_by_tag_name($tag_name)};
    }
  }
  return $result;
}

sub get_elements_by_class_name {
  ## A slight extension of typical getElementsByClassName
  ## @param Class name OR ArrayRef of multiple class names
  ## @return ArrayRef of Element objects
  my ($self, $class_name) = @_;
  
  $class_name = [ $class_name ] unless ref($class_name) eq 'ARRAY';

  my $attrib_set = [];
  push @$attrib_set, {'class'=> $_} for @$class_name;

  return $self->get_elements_by_attribute($attrib_set);
}

sub get_elements_by_attribute {
  ## Gets all the elements inside a node with the given attribute and value
  ## @param Attribute name OR ref of hash with keys as attributes in case of multiple attributes or ref of array of such hashes
  ##  - A Hash with multiple keys will give the intersection of selections of individual key attribute and value
  ##  - An Array with multiples hashes, will return the union of selections of individual hash
  ##  - examples:
  ##  - - - [{'type' => 'text'}, {'class' => 'string'}] will return all the elements with EITHER type=text OR class=string
  ##  - - - {'type' => 'text', 'class' => 'string'} will return all elements with BOTH type=text AND class=string
  ##  - - - {'type' => ['password', 'text']} will return all elements with type=password OR type=text
  ##  - - - {'type' => ['password', 'text'], 'class' => 'string'} will return elements with type=password or type=text, but class=string always 
  ##  - - - [{'type' => 'password', 'class' => 'string'}, {'type' => 'text', 'class' => 'string'}] will give same results as above 
  ## @param Attribute value, if first argument 1 if attribute name
  ## @return ArrayRef of Element objects
  my $self = shift;

  #works for document or element only
  return [] unless $self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE;

  my $attrib_set = shift;
  $attrib_set = { $attrib_set => shift }  if ref($attrib_set) !~ /^(ARRAY|HASH)$/;
  $attrib_set = [ $attrib_set ]           if ref($attrib_set) ne 'ARRAY';

  my $result = [];
  
  foreach my $child_node (@{$self->child_nodes}) {
    next unless $child_node->node_type == $self->ELEMENT_NODE;
    foreach my $attrib_pairs_hash (@{$attrib_set}) { #at least one needs to be matching (ie. match found ? break the loop : try next)
      my $match_found     = 0;
      my $match_required  = 0;
      foreach my $attrib_name (keys %$attrib_pairs_hash) { #all need to be matching (ie. match found ? try next : break the loop)
        $match_required++;
        last unless $child_node->has_attribute($attrib_name); #break the loop if no match found
        my $attrib_val = $attrib_pairs_hash->{$attrib_name};
        $attrib_val = [ $attrib_val ] if ref($attrib_val) ne 'ARRAY';
        if ($attrib_name =~ /^(class|style)$/) {
          exists $child_node->{'_attributes'}{$attrib_name}{$_} and ++$match_found and last for @$attrib_val; #at least one needs to be matching
        }
        else {
          $child_node->{'_attributes'}{$attrib_name} eq $_ and ++$match_found and last for @$attrib_val; #at least one needs to be matching
        }
        last unless $match_found == $match_required; #break the loop if no match found
      }
      push @$result, $child_node and last if $match_found && $match_found == $match_required; #match found, break the loop
    }
    push @$result, @{$child_node->get_elements_by_attribute($attrib_set)};
  }
  return $result;
}

sub ancestors {
  ## Returns all the ancestors of the node, immediate parent node being at index [0]
  ## @return ArrayRef of Element objects or empty array if no parent
  my $parent = shift->parent_node;
  return $parent ? [$parent, @{$parent->ancestors}] : [];
}

sub get_ancestor_by_id {
  ## Gets the most recent ancestor element with the given id
  ## @param id of the ancestor node
  ## @return Element object or undef
  my ($self, $id) = @_;
  return $self->get_ancestor_by_attribute('id', $id);
}

sub get_ancestor_by_name {
  ## Gets the most recent ancestor element with the given name
  ## @param name
  ## @return Element object or undef
  my ($self, $name) = @_;
  return $self->get_ancestor_by_attribute('name', $name);
}

sub get_ancestor_by_tag_name {
  ## Gets the most recent ancestor element with the given tag name
  ## @param Tag name
  ## @return Element object or undef
  my ($self, $tag_name) = @_;
  
  ## works for element and text node only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->TEXT_NODE || $self->node_type == $self->COMMENT_NODE) {
    my $ancestor = $self->parent_node;
    while ($ancestor && $ancestor->node_type == $self->ELEMENT_NODE) {
      return $ancestor if $ancestor->node_name eq $tag_name;
      $ancestor = $ancestor->parent_node;
    }
  }
  return undef;
}

sub get_ancestor_by_class_name {
  ## Gets the most recent ancestor element with the given class name
  ## @param Class name
  ## @return Node object or undef
  my ($self, $class_name) = @_;
  return $self->get_ancestor_by_attribute('class', $class_name);
}

sub get_ancestor_by_attribute {
  ## Gets the most recent ancestor element with the given attribute and value
  ## @param Attribute name
  ## @param Attribute value
  ## @return Element object or undef
  my ($self, $attrib, $value) = @_;

  ## works for element and text node only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->TEXT_NODE || $self->node_type == $self->COMMENT_NODE) {
    my $ancestor = $self->parent_node;
    while ($ancestor && $ancestor->node_type == $self->ELEMENT_NODE) {
      if ($attrib =~ /^(class|style)$/) {
        return $ancestor if $ancestor->has_attribute($attrib) && exists $ancestor->{'_attributes'}{$attrib}{$value};
      }
      else {
        return $ancestor if $ancestor->get_attribute($attrib) eq $value;
      }
      $ancestor = $ancestor->parent_node;
    }
  }
  return undef;
}

sub get_nodes_by_flag {
  ## Gets all the child nodes (recursively) of the node with the given flag
  ## Independent of node type
  ## @param Either of the following
  ##  - String flag name                                - single flag with default value (ie. 1)
  ##  - ArrayRef of flag Strings [flag1, flag2, ... ]   - to accomodate multiple flags with default value
  ##  - HashRef {flag1 => value1, flag2 => value2 ...}  - to accomodate multiple flags with custom values
  ##  - HashRef {flag1 => [a, b ... ], flag2 => c ...}  - to accomodate multiple flag values
  my $self  = shift;
  my $flag  = shift;
  my $recur = scalar @_ ? shift : 1;

  $flag = [ $flag ]                 if ref($flag) !~ /^(ARRAY|HASH)$/;
  $flag = { map {$_ => 1} @$flag }  if ref($flag) eq 'ARRAY';
  ref($flag->{$_}) ne 'ARRAY' and $flag->{$_} = [$flag->{$_}] for keys %$flag;

  my $nodes = [];
  foreach my $child_node (@{$self->child_nodes}) {
    FLAG: foreach my $flag_name (keys %$flag) {
      foreach my $flag_value (@{$flag->{$flag_name}}) {
        push @$nodes, $child_node and last FLAG if exists $child_node->{'_flags'}{$flag_name} && $child_node->{'_flags'}{$flag_name} eq $flag_value;
      }
    }
    push @$nodes, $child_node->get_nodes_by_flag($flag) if $recur;
  }
  return $nodes;
}

sub get_child_nodes_by_flag {
  ## Gets all the child nodes (immediate children only) of the node with the given flag
  ## Independent of node type
  ## @param As accepted by get_nodes_by_flag
  return shift->get_nodes_by_flag(shift, 0);
}

sub has_child_nodes {
  ## Checks if the node has any child nodes
  ## @return 1 or 0 accordingly
  return scalar @{shift->{'_child_nodes'}} ? 1 : 0;
}

sub child_nodes {
  ## Getter for child elements
  ## @return ArrayRef of Node objects
  return shift->{'_child_nodes'};
}

sub first_child {
  ## Getter for first child node
  ## @return Node object
  return shift->{'_child_nodes'}->[0] || undef;
}

sub last_child {
  ## Getter for last child node
  ## @return Node object
  return shift->{'_child_nodes'}->[-1] || undef;
}

sub next_sibling {
  ## Getter for next node
  ## @return Node object
  return shift->{'_next_sibling'} || undef;
}

sub previous_sibling {
  ## Getter for previous node
  ## @return Previous Node object
  return shift->{'_previous_sibling'} || undef;
}

sub parent_node {
  ## Getter for parent Node
  ## @return Parent Node object
  return shift->{'_parent_node'} || undef;
}

sub appendable {
  ## Checks if a given node can be appended in this node
  ## @param Node to be appended
  ## @param (Optional) Reference to a SCALAR string to which error will be saved if any
  ## @return 1 if appendable, 0 otherwise
  my ($self, $node, $error_ref) = @_;
    
  my $no_error = $error_ref && ref($error_ref) eq 'SCALAR' ? 0 : 1;

  #first filter - if the node can not have any child by default
  ($no_error or $$error_ref = "Node can not have any child node.") and return 0 unless $self->can_have_child;

  #second filter - if invalid node
  ($no_error or $$error_ref = "Node tried to append is invalid.") and return 0 unless defined $node && $node->isa(__PACKAGE__);

  #third filter - if the node being appended as child is one of this node's ancestors
  my $ancestor = $self->parent_node;
  while (defined $ancestor) {
    ($no_error or $$error_ref = "Node tried to append is one of node's ancestors.") and return 0 if $ancestor->is_same_node($node);
    $ancestor = $ancestor->parent_node;
  }
  return 1;
}

sub append_child {
  ## Appends a child node
  ## @param New node
  ## @return New node if success, undef otherwise
  my ($self, $child) = @_;
  my $error = "";
  if ($self->appendable($child, \$error)) {
    $child->remove; #remove from present parent node, if any
    $child->{'_parent_node'} = $self;
    if ($self->has_child_nodes) {
      $child->{'_previous_sibling'} = $self->last_child;
      $self->last_child->{'_next_sibling'} = $child;
    }
    push @{$self->{'_child_nodes'}}, $child;
    return $child;
  }
  warn 'Node cannot be inserted at the specified point in the hierarchy. '.$error;
  return undef;
}

sub prepend_child {
  ## Appends a child node at the beginning
  ## @param Node to be appended
  ## @return new child Node object if success, undef otherwise
  my ($self, $child) = @_;
  return $self->has_child_nodes
    ? $self->insert_before($child, $self->first_child)
    : $self->append_child($child);
}

sub insert_before {
  ## Appends a child node before a given reference node
  ## @param New node
  ## @param Reference node
  ## @return New Node object if successfully added, undef otherwise
  my ($self, $new_node, $reference_node) = @_;
  
  if (defined $reference_node && $self->is_same_node($reference_node->parent_node) && !$reference_node->is_same_node($new_node)) {
  
    return undef unless $self->append_child($new_node);
    $new_node->previous_sibling->{'_next_sibling'} = 0;
    $new_node->{'_next_sibling'} = $reference_node;
    $new_node->{'_previous_sibling'} = $reference_node->previous_sibling || 0;
    $reference_node->previous_sibling->{'_next_sibling'} = $new_node if $reference_node->previous_sibling;
    $reference_node->{'_previous_sibling'} = $new_node;
    $self->_adjust_child_nodes;
    return $new_node;
  }
  warn 'Reference node is missing or is same as new node or does not belong to the same parent node.';
  return undef;
}

sub insert_after {
  ## Appends a child node after a given reference node
  ## @param New node
  ## @param Reference node
  ## @return New node if success, undef otherwise
  my ($self, $new_node, $reference_node) = @_;
  return defined $reference_node->next_sibling
    ? $self->insert_before($new_node, $reference_node->next_sibling)
    : $self->append_child($new_node);
}

sub before {
  ## Places a new node before the node. An extra to DOM function to make it easy to insert nodes.
  ## @param New Node if success, undef otherwise
  my ($self, $new_node) = @_;
  unless ($self->parent_node) {
    warn "New node could not be inserted. Either the reference node is top level or has not been added to the DOM tree yet.";
    return undef;
  }
  return $self->parent_node->insert_before($new_node, $self);
}

sub after {
  ## Places a new node after the node. An extra to DOM function to make it easy to insert nodes.
  ## @param New Node if success, undef otherwise
  my ($self, $new_node) = @_;
  unless ($self->parent_node) {
    warn "New node could not be inserted. Either the reference node is top level or has not been added to the DOM tree yet.";
    return undef;
  }
  return $self->parent_node->insert_after($new_node, $self);
}

sub clone_node {
  ## Clones the node
  ## Only properties defined in this class will be cloned - including flags (If flags not required, do reset_flags() after cloning)
  ## @param 1/0 depending upon if child nodes also need to be cloned (deep cloning)
  ## @return New node
  my ($self, $deep_clone) = @_;
  
  my $clone = bless {
    '_attributes'       => clone($self->{'_attributes'}),
    '_flags'            => clone($self->{'_flags'}),
    '_child_nodes'      => [],
    '_text'             => defined $deep_clone && $deep_clone == 1 ? $self->{'_text'} : '',
    '_dom'              => $self->dom,
    '_parent_node'      => 0,
    '_next_sibling'     => 0,
    '_previous_sibling' => 0,
  }, ref($self);
  
  return $clone unless defined $deep_clone && $deep_clone == 1;
  
  my $previous_sibling = 0;
  for (@{$self->child_nodes}) {
    my $child_clone = $_->clone_node(1);
    $child_clone->{'_parent_node'} = $clone;
    $child_clone->{'_previous_sibling'} = $previous_sibling;
    $previous_sibling->{'_next_sibling'} = $child_clone if $previous_sibling;
    $previous_sibling = $child_clone; #for next loop
    push @{$clone->{'_child_nodes'}}, $child_clone;
  }
  return $clone;
}

sub remove_child {
  ## Removes a child node
  ## @param Node to be removed
  ## @return Removed node
  my ($self, $child) = @_;
  if ($self->is_same_node($child->parent_node)) {
    $child->previous_sibling->{'_next_sibling'} = $child->next_sibling || 0 if defined $child->previous_sibling;
    $child->next_sibling->{'_previous_sibling'} = $child->previous_sibling || 0 if defined $child->next_sibling;
    $child->{'_next_sibling'} = 0;
    $child->{'_previous_sibling'} = 0;
    $child->{'_parent_node'} = 0;
    $self->_adjust_child_nodes;
    return $child;
  }
  warn 'Node was not found in the parent node.';
    return undef;
}

sub remove {
  ## Removes the child from it's parent node. An extra to DOM function to make it easy to remove nodes
  my $self = shift;
  $self->parent_node->remove_child($self) if defined $self->parent_node;
  return $self;
}

sub remove_children {
  ## Removes all the child nodes
  ## @return ArrayRef of all removed nodes
  my $self = shift;
  my $children = $self->{'_child_nodes'};
  $_->{'_next_sibling'} = $_->{'_previous_sibling'} = $_->{'_parent_node'} = 0 for @{$children};
  $self->{'_child_nodes'} = [];
  return $children;
}

sub replace_child {
  ## Replaces a child node with another
  ## @param New Node
  ## @param Old Node
  ## @return Removed node
  my ($self, $new_node, $old_node) = @_;
  return $self->remove_child($old_node) if $self->insert_before($new_node, $old_node);
}

sub is_empty {
  ## @return 1 or 0 if node is empty or not resp.
  my $self = shift;
  return $self->{'_text'} ne '' || $self->has_child_nodes ? 0 : 1;
}

sub dom {
  ## Getter for owner DOM
  ## @return DOM object
  return shift->{'_dom'};
}

sub encode_htmlentities {
  #use this to avoid using HTML::entities in every child
  my $self = shift;
  return encode_entities(shift);
}

sub decode_htmlentities {
  #use this to avoid using HTML::entities in every child
  my $self = shift;
  return decode_entities(shift);
}

sub unique_id {
  ## Gives a random unique string
  ## @return Unique string
  shift;
  return EnsEMBL::Web::Tools::RandomString::random_string(@_);
}

sub is_same_node {
  # Compares memory location of two Node obects
  # @return 1 if same object, 0 otherwise
  my ($self, $other) = @_;
  return 0 unless defined $other;
  return $self eq $other ? 1 : 0;
}

sub dump {
  # Dumps the tree considering the node to be the top level
  # Can be helpful in debuging the tree
  my ($self, $indent, $output) = @_;
  my $do_warn = 0;
  $output = [] and $do_warn = 1 and $indent = '- ' unless ($indent);
  
  (my $string = "$self") =~ s/EnsEMBL\:\:Web\:\://;
  my $extras = [], my %attr, my $val, my $i = 0;
  push @$extras, '<'.$self->node_name.'>' if $self->node_type == $self->ELEMENT_NODE;
  push @$extras, '"'.$self->{'_text'}.'"' if $self->node_type == $self->TEXT_NODE;
  push @$extras, '[document node]'        if $self->node_type == $self->DOCUMENT_NODE;
  foreach my $attrib_name (keys %{$self->{'_attributes'}}) {
    if ($attrib_name =~ /^(style|class)$/) {
      $1 eq 'style' and $attr{$i++.$1} = $_.':'.$self->{'_attributes'}{$1}{$_}
      or $1 eq 'class' and $attr{$i++.$1} = $_ for keys %{$self->{'_attributes'}{$1}};
    }
    else {
      $attr{$i++.$attrib_name} = $self->{'_attributes'}{$attrib_name};
    }
  }
  $val = substr $_, 1 and push @$extras, qq($val = "$attr{$_}") for keys %attr;
  push @$extras, qq(flag:$_ = "$self->{'_flags'}{$_}") for keys %{$self->{'_flags'}};
  push @$extras, qq(element_type = ).$self->element_type if $self->node_type == $self->ELEMENT_NODE;
  $string .= ' {'.join(', ', @$extras).'}';
  push @$output, $indent.$string;
  $_->dump($indent.'- ', $output) for @{$self->child_nodes};
  warn Data::Dumper->Dump([$output], ['________TREE________']) if $do_warn;
}

sub _adjust_child_nodes {
  # private function used to adjust the array referenced at _child_nodes key after some changes in the child nodes
  # removes the 'just-removed' nodes from the array
  # re-arranges the array on the bases of linked list
  my $self = shift;
  return unless $self->has_child_nodes;   #has already no child nodes

  my $adjusted  = [];
  
  #avoid pointing initially to any removed node
  my $node = undef;
  for (@{$self->{'_child_nodes'}}) {
    if (defined $_->parent_node && $self->is_same_node($_->parent_node)) {
      $node = $_;
      last;
    }
  }

  if (defined $node) {

    #set the pointer to the first node
    $node = $node->previous_sibling while defined $node->previous_sibling;

    #sort the array wrt the linked list
    while (defined $node) {
      push @$adjusted, $node;
      $node = $node->next_sibling;
    }
  }

  $self->{'_child_nodes'} = $adjusted;
}

1;

