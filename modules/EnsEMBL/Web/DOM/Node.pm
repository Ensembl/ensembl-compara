package EnsEMBL::Web::DOM::Node;

## Status - Under Development

use strict;
use warnings;
use HTML::Entities qw(encode_entities decode_entities);
use Clone qw(clone);

use base qw(EnsEMBL::Web::Root);
use EnsEMBL::Web::DOM;

use constant {
  ELEMENT_NODE                 => 1,
  TEXT_NODE                    => 3,
  COMMENT_NODE                 => 8,
  DOCUMENT_NODE                => 9,
};

sub new {
  ## @constructor
  ## @params DOM object 
  my ($class, $dom) = @_; #TODO - remove the argument and get dom from hub/object(?) etc if possible -
  return bless {
    '_attributes'           => {},
    '_child_nodes'          => [],
    '_text'                 => '',
    '_dom'                  => $dom || new EnsEMBL::Web::DOM, #TODO
    '_parent_node'          => 0,
    '_next_sibling'         => 0,
    '_previous_sibling'     => 0,
  }, $class;
}

sub can_have_child {
  ## Tell whether this node can have child elements
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
  ## @return HTML
  return '';
}

sub get_element_by_id {
  ## Typical getElementById
  ## @params Element id
  ## @returns Element object
  my ($self, $id) = @_;

  #works for document or element only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE) {
    for (@{ $self->child_nodes }) {
      return $_ if $_->id eq $id;
      return $_->get_element_by_id($id);
    }
  }
  return undef;
}

sub get_elements_by_name {
  ## Typical getElementsByName
  ## @params name
  ## @returns ArrayRef of Element objects
  my ($self, $name) = @_;
  
  my $result = [];

  #works for document or element only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE) {
    for (@{ $self->child_nodes }) {
      push @$result, $_ if $_->name eq $name;
      push @$result, @{ $_->get_elements_by_name($name) };
    }
  }
  return $result;
}

sub get_elements_by_tag_name {
  ## A slight extension of typical getElementsByTagName
  ## @params Tag name (string) or ArrayRef of multiple tag names
  ## @returns ArrayRef of Element objects
  my ($self, $tag_name) = @_;
  
  $tag_name     = [ $tag_name ] unless ref($tag_name) eq 'ARRAY';
  my $tag_hash  = { map {$_ => 1} @{ $tag_name } };
  my $result    = [];

  #works for document or element only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE) {
    for (@{ $self->child_nodes }) {
      push @$result, $_ if exists $tag_hash->{ $_->node_name };
      push @$result, @{ $_->get_elements_by_tag_name($tag_name) };
    }
  }
  return $result;
}

sub get_elements_by_class_name {
  ## Typical getElementsByClassName
  ## @params Class name
  ## @returns ArrayRef of Element objects
  my ($self, $class_name) = @_;
  
  my $result = [];

  #works for document or element only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE) {
    for (@{ $self->child_nodes }) {
      push @$result, $_ if $_->has_attribute('class') && exists $_->get_attribute('class')->{ $class_name };
      push @$result, @{ $_->get_elements_by_class_name($class_name) };
    }
  }
  return $result;
}

sub has_child_nodes {
  ## Checks if the element has any child nodes
  ## @return 1 or 0 accordingly
  return scalar @{ shift->{'_child_nodes'} } ? 1 : 0;
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
  ## Checks if a given node can be appended in this node (needs to check the allowed_child_nodes function first)
  ## @params Node to be appended
  ## @return 1 if appendable, 0 otherwise
  my ($self, $node) = @_;

  #first filter - if the node can not have any child by default
  return 0 unless $self->can_have_child;

  #second filter - if invalid node
  return 0 if not defined $node || not defined $node->node_name || $node->node_name eq '';

  #third filter - if the node to put in is one of this node's ancestors
  my $ancestor = $self->parent_node;
  while (defined $ancestor) {
    return 0 if $ancestor->is_same_as($node);
    $ancestor = $ancestor->parent_node;
  }
  
  return $self->_appendable($node);
}

sub _appendable {
  ## Adds another filter to appendable method
  ## Override in child classes
  return 1;
}

sub append_child {
  ## Appends a child element
  ## @params New element
  ## @return 1 if success, 0 otherwise
  my ($self, $element) = @_;
  if ($self->appendable($element)) {
    $element->parent_node->remove_child($element) if defined $element->parent_node; #remove from present parent node, if any
    $element->{'_parent_node'} = $self;
    if ($self->has_child_nodes) {
      $element->{'_previous_sibling'} = $self->last_child;
      $self->last_child->{'_next_sibling'} = $element;
    }
    push @{ $self->{'_child_nodes'} }, $element;
    return 1;
  }
  else {
    warn 'Node cannot be inserted at the specified point in the hierarchy.';
    return 0;
  }
}

sub insert_before {
  ## Appends a child element before a given reference element
  ## @params New element
  ## @params Reference element
  ## @return 1 if successfully added, 0 otherwise

  my ($self, $new_element, $reference_element) = @_;
  
  if (defined $reference_element && $self->is_same_as($reference_element->parent_node) && !$reference_element->is_same_as($new_element)) {
  
    return 0 unless $self->append_child($new_element);
    $new_element->previous_sibling->{'_next_sibling'} = 0;
    $new_element->{'_next_sibling'} = $reference_element;
    $new_element->{'_previous_sibling'} = $reference_element->previous_sibling || 0;
    $reference_element->previous_sibling->{'_next_sibling'} = $new_element if $reference_element->previous_sibling;
    $reference_element->{'_previous_sibling'} = $new_element;
    $self->_adjust_child_nodes;
    return 1;
  }
  warn 'Reference element is missing or is same as new element or does not belong to the same parent node.';
  return 0;
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

sub insert_at_beginning {
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
  ## @param 1/0 depending upon if child elements also need to be cloned (deep cloning)
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
  for (@{ $self->child_nodes }) {
    my $child_clone = $_->clone_node(1);
    $child_clone->{'_parent_node'} = $clone;
    $child_clone->{'_previous_sibling'} = $previous_sibling;
    $previous_sibling->{'_next_sibling'} = $child_clone if $previous_sibling;
    $previous_sibling = $child_clone;
    push @{ $clone->{'_child_nodes'} }, $child_clone;
  }
  return $clone;  
}

sub remove_child {
  ## Removes a child element
  ## @param Element to be removed
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
}

sub replace_child {
  ## Replaces a child element with another
  ## @param New Element
  ## @param Old Element
  ## @return Removed element
  my ($self, $new_element, $old_element) = @_;
  return $self->remove_child($old_element) if $self->insert_before($new_element, $old_element);
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
  for (@{ $self->{'_child_nodes'} }) {
    if (defined $_->parent_node) {
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

