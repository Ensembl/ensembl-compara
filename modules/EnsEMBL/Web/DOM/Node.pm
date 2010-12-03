package EnsEMBL::Web::DOM::Node;

use strict;

use HTML::Entities qw(encode_entities decode_entities);
use Clone qw(clone);

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
  ## @params DOM object 
  my ($class, $dom) = @_;
  return bless {
    '_attributes'           => {},
    '_child_nodes'          => [],
    '_text'                 => '',
    '_dom'                  => $dom || new EnsEMBL::Web::DOM, #creates new DOM object if not provided as arg
    '_parent_node'          => 0,
    '_next_sibling'         => 0,
    '_previous_sibling'     => 0,
  }, $class;
}

sub can_have_child {
  ## Tells whether this node can have child elements
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

sub get_element_by_id {
  ## Typical getElementById
  ## @params Element id
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
  ## @params name or ArrayRef of multiple names
  ## @return ArrayRef of Element objects
  my ($self, $name) = @_;
  
  $name         = [ $name ] unless ref($name) eq 'ARRAY';
  my $name_hash = { map {$_ => 1} @{$name} };
  my $result    = [];

  #works for document or element only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE) {
    for (@{$self->child_nodes}) {
      next unless $_->node_type == $self->ELEMENT_NODE;
      push @$result, $_ if exists $name_hash->{$_->name} eq $name;
      push @$result, @{$_->get_elements_by_name($name)};
    }
  }
  return $result;
}

sub get_elements_by_tag_name {
  ## A slight extension of typical getElementsByTagName
  ## @params Tag name (string) or ArrayRef of multiple tag names
  ## @return ArrayRef of Element objects
  my ($self, $tag_name) = @_;
  
  $tag_name     = [ $tag_name ] unless ref($tag_name) eq 'ARRAY';
  my $tag_hash  = { map {$_ => 1} @{$tag_name} };
  my $result    = [];

  #works for document or element only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE) {
    for (@{$self->child_nodes}) {
      next unless $_->node_type == $self->ELEMENT_NODE;
      push @$result, $_ if exists $tag_hash->{$_->node_name};
      push @$result, @{$_->get_elements_by_tag_name($tag_name)};
    }
  }
  return $result;
}

sub get_elements_by_class_name {
  ## A slight extension of typical getElementsByClassName
  ## @params Class name OR ArrayRef of multiple class names
  ## @return ArrayRef of Element objects
  my ($self, $class_name) = @_;
  
  $class_name = [ $class_name ] unless ref($class_name) eq 'ARRAY';

  my $attrib_set = [];
  push @$attrib_set, ['class', $_] for @$class_name;

  return $self->get_elements_by_attribute($attrib_set);
}

sub get_elements_by_attribute {
  ## Gets all the elements inside a node with the given attribute and value
  ## @params Attribute name OR ArrayRef of [[attrib1, value1], [attrib2, value2], [attrib3, value3]] for multiple attributes
  ## @params Attribute value
  ## @return ArrayRef of Element objects
  my $self = shift;

  #works for document or element only
  return [] unless $self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE;

  my $attrib_set = shift;
  if (ref($attrib_set) ne 'ARRAY') {
    $attrib_set = [[ $attrib_set, shift ]];
  }
  elsif (scalar @$attrib_set && ref($attrib_set->[0]) ne 'ARRAY') {
    $attrib_set = [ $attrib_set ];
  }

  my $result = [];
  
  foreach my $child_node (@{$self->child_nodes}) {
    next unless $child_node->node_type == $self->ELEMENT_NODE;
    for (@{$attrib_set}) {
      if ($_->[0] =~ /^(class|style)$/) {
        push @$result, $child_node if $child_node->has_attribute($_->[0]) && exists $child_node->{'_attributes'}{$_->[0]}{$_->[1]};
      }
      else {
        push @$result, $child_node if $child_node->get_attribute($_->[0]) eq $_->[1];
      }
    }
    push @$result, @{$child_node->get_elements_by_attribute($attrib_set)};
  }
  return $result;
}

sub get_ancestor_by_id {
  ## Gets the most recent ancestor with the given id
  ## @params id of the ancestor
  ## @return Element object or undef
  my ($self, $id) = @_;
  return $self->get_ancestor_by_attribute('id', $id);
}

sub get_ancestor_by_name {
  ## Gets the most recent ancestor with the given name
  ## @params name
  ## @return Element object or undef
  my ($self, $name) = @_;
  return $self->get_ancestor_by_attribute('name', $name);
}

sub get_ancestor_by_tag_name {
  ## Gets the most recent ancestor with the given tag name
  ## @params Tag name
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
  ## Gets the most recent ancestor with the given class name
  ## @params Class name
  ## @return Element object or undef
  my ($self, $class_name) = @_;
  return $self->get_ancestor_by_attribute('class', $class_name);
}

sub get_ancestor_by_attribute {
  ## Gets the most recent ancestor with the given attribute and value
  ## @params Attribute name
  ## @params Attribute value
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

sub has_child_nodes {
  ## Checks if the element has any child nodes
  ## @return 1 or 0 accordingly
  return scalar @{shift->{'_child_nodes'}} ? 1 : 0;
}

sub child_nodes {
  ## Getter for child elements
  ## @return ArrayRef of all child elements
  return shift->{'_child_nodes'};
}

sub first_child {
  ## Getter for first child element
  ## @return First child element
  return shift->{'_child_nodes'}->[0] || undef;
}

sub last_child {
  ## Getter for last child element
  ## @return Last child element
  return shift->{'_child_nodes'}->[-1] || undef;
}

sub next_sibling {
  ## Getter for next element
  ## @return Next element
  return shift->{'_next_sibling'} || undef;
}

sub previous_sibling {
  ## Getter for previous element
  ## @return Previous element
  return shift->{'_previous_sibling'} || undef;
}

sub parent_node {
  ## Getter for parent Element
  ## @return Parent element
  return shift->{'_parent_node'} || undef;
}

sub appendable {
  ## Checks if a given node can be appended in this node
  ## @params Node to be appended
  ## @return 1 if appendable, 0 otherwise
  my ($self, $node) = @_;

  #first filter - if the node can not have any child by default
  return 0 unless $self->can_have_child;

  #second filter - if invalid node
  return 0 if not defined $node || not defined $node->node_name || $node->node_name eq '';

  #third filter - if the node being appended as child is one of this node's ancestors
  my $ancestor = $self->parent_node;
  while (defined $ancestor) {
    return 0 if $ancestor->is_same_as($node);
    $ancestor = $ancestor->parent_node;
  }
  
  ##finally run some individual filters before giving any result
  return $self->_appendable($node);
}

sub _appendable {
  ## Adds another filter to appendable method
  ## Override in child classes - only if validation required
  return 1; #no extra filter by default
}

sub append_child {
  ## Appends a child element
  ## @params New element
  ## @return New element if success, undef otherwise
  my ($self, $element) = @_;
  if ($self->appendable($element)) {
    $element->remove; #remove from present parent node, if any
    $element->{'_parent_node'} = $self;
    if ($self->has_child_nodes) {
      $element->{'_previous_sibling'} = $self->last_child;
      $self->last_child->{'_next_sibling'} = $element;
    }
    push @{$self->{'_child_nodes'}}, $element;
    return $element;
  }
  else {
    warn 'Node cannot be inserted at the specified point in the hierarchy.';
    return undef;
  }
}

sub insert_before {
  ## Appends a child element before a given reference element
  ## @params New element
  ## @params Reference element
  ## @return New element if successfully added, undef otherwise
  my ($self, $new_element, $reference_element) = @_;
  
  if (defined $reference_element && $self->is_same_as($reference_element->parent_node) && !$reference_element->is_same_as($new_element)) {
  
    return undef unless $self->append_child($new_element);
    $new_element->previous_sibling->{'_next_sibling'} = 0;
    $new_element->{'_next_sibling'} = $reference_element;
    $new_element->{'_previous_sibling'} = $reference_element->previous_sibling || 0;
    $reference_element->previous_sibling->{'_next_sibling'} = $new_element if $reference_element->previous_sibling;
    $reference_element->{'_previous_sibling'} = $new_element;
    $self->_adjust_child_nodes;
    return $new_element;
  }
  warn 'Reference element is missing or is same as new element or does not belong to the same parent node.';
  return undef;
}

sub insert_after {
  ## Appends a child element after a given reference element
  ## If reference element is missing, new element is appended in the end
  ## @params New element
  ## @params Reference element
  ## @return 1 if success, 0 otherwise
  my ($self, $new_element, $reference_element) = @_;
  return defined $reference_element->next_sibling
    ? $self->insert_before($new_element, $reference_element->next_sibling)
    : $self->append_child($new_element);
}

sub prepend_child {
  ## Appends a child element at the beginning
  ## @params Element to be appended
  ## @return 1 if success, 0 otherwise
  my ($self, $element) = @_;
  return $self->has_child_nodes
    ? $self->insert_before($element, $self->first_child)
    : $self->append_child($element);
}

sub clone_node {
  ## Clones an element
  ## Only properties defined in this class will be cloned
  ## @params 1/0 depending upon if child elements also need to be cloned (deep cloning)
  ## @return New element
  my ($self, $deep_clone) = @_;
  
  my $clone = bless {
    '_attributes'       => clone($self->{'_attributes'}),
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
  ## Removes a child element
  ## @params Element to be removed
  ## @return Removed element
  my ($self, $element) = @_;
  if ($self->is_same_as($element->parent_node)) {
    $element->previous_sibling->{'_next_sibling'} = $element->next_sibling || 0 if defined $element->previous_sibling;
    $element->next_sibling->{'_previous_sibling'} = $element->previous_sibling || 0 if defined $element->next_sibling;
    $element->{'_next_sibling'} = 0;
    $element->{'_previous_sibling'} = 0;
    $element->{'_parent_node'} = 0;
    $self->_adjust_child_nodes;
    return $element;
  }
  warn 'Element was not found in the parent node.';
    return undef;
}

sub replace_child {
  ## Replaces a child element with another
  ## @params New Element
  ## @params Old Element
  ## @return Removed element
  my ($self, $new_element, $old_element) = @_;
  return $self->remove_child($old_element) if $self->insert_before($new_element, $old_element);
}

sub remove {
  ## Removes the child from it's parent node. An extra to DOM function to make it easy to remove elements
  my $self = shift;
  $self->parent_node->remove_child($self) if defined $self->parent_node;
  return $self;
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

sub is_same_as {
  # Compares memory location of two Node obects
  # @return 1 if same object, 0 otherwise
  my ($self, $other) = @_;
  return 0 unless defined $other;
  return $self eq $other ? 1 : 0;
}

sub _adjust_child_nodes {
  # private function used to adjust the array referenced at _child_nodes key after some change in the child nodes
  # removes the 'just-removed' nodes from the array
  # re-arranges the array on the bases of linked list
  my $self = shift;
  return unless $self->has_child_nodes;   #has already no child nodes

  my $adjusted  = [];
  
  #avoid pointing initially to any removed node
  my $node = undef;
  for (@{$self->{'_child_nodes'}}) {
    if (defined $_->parent_node && $self->is_same_as($_->parent_node)) {
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

