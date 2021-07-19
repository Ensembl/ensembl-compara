=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::DOM::Node;

use strict;

use HTML::Entities qw(encode_entities decode_entities);
use Clone qw(clone);
use Data::Dumper;

use EnsEMBL::Web::DOM;
use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::Utils::RandomString qw(random_string);

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
    '_dom'                  => $dom || EnsEMBL::Web::DOM->new, #creates DOM->new object if not provided as arg
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

sub set_flags {
  ## Sets/modifies multiple flags
  ## @param Either string, or arrayref or hashref
  ##   - string: flag with the given name will be set on
  ##   - hashref: will add all the keys as flags with corresponding values
  ##   - arrayref: will be iterated through all the elements to set_flags (so each element can be either a hashref or string)
  ## @return no return value
  my ($self, $flags) = @_;
  if (ref $flags && ref $flags eq 'ARRAY') {
    $self->set_flags($_) for @$flags;
    return;
  }
  if (!ref $flags) {
    $flags = { $flags => 1 };
  }
  $self->{'_flags'}{$_} = defined $flags->{$_} ? $flags->{$_} : 1 for keys %$flags;
}

sub get_flag {
  ## Gets previously set flag
  ## @param flag name
  ## @return flag value if set or undef if not
  my ($self, $flag) = @_;
  return exists $self->{'_flags'}{$flag} ? $self->{'_flags'}{$flag} : undef;
}

sub has_flag {
  ## Tells whether a flag has been set or not
  ## @param Flag name
  ## @return 1 or 0 accordingly
  my ($self, $flag) = @_;
  return exists $self->{'_flags'}{$flag} ? 1 : 0;
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

sub render_text {
  ## Outputs the node's text
  ## Override in child class
  ## @return output text
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
  ## @return Element object, undef if no element found
  my ($self, $id) = @_;

  #works for document and element only
  if ($self->node_type == $self->ELEMENT_NODE || $self->node_type == $self->DOCUMENT_NODE) {
    for (@{$self->child_nodes}) {
      next unless $_->node_type == $self->ELEMENT_NODE;
      return $_ if $_->get_attribute('id') eq $id;
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
  ##  - String flag name                                - single flag with any value
  ##  - ArrayRef of flag Strings [flag1, flag2, ... ]   - to accomodate multiple flags with any values
  ##  - HashRef {flag1 => value1, flag2 => value2 ...}  - to accomodate multiple flags with custom values
  ##  - HashRef {flag1 => [a, b ... ], flag2 => c ...}  - to accomodate multiple flag values
  ## @return ArrayRef of nodes
  my $self  = shift;
  my $flag  = shift;
  my $recur = scalar @_ ? shift : 1;

  $flag = [ $flag ]                     if ref($flag) !~ /^(ARRAY|HASH)$/;
  $flag = { map {$_ => undef} @$flag }  if ref($flag) eq 'ARRAY';
  ref($flag->{$_}) ne 'ARRAY' and $flag->{$_} = [$flag->{$_}] for keys %$flag;
  
  my $nodes = [];
  foreach my $child_node (@{$self->child_nodes}) {
    FLAG: foreach my $flag_name (keys %$flag) {
      foreach my $flag_value (@{$flag->{$flag_name}}) {
        push @$nodes, $child_node and last FLAG if exists $child_node->{'_flags'}{$flag_name} && (!defined $flag_value || $child_node->{'_flags'}{$flag_name} eq $flag_value);
      }
    }
    push @$nodes, @{$child_node->get_nodes_by_flag($flag)} if $recur;
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
  ## @param (Optional) Reference to a SCALAR string to which 'reason why node can't be appended' will be saved if any
  ## @return 1 if appendable, 0 otherwise
  my ($self, $node, $reason) = @_;
    
  my $ignore_reason = $reason && ref($reason) eq 'SCALAR' ? 0 : 1;

  #first filter - if the node can not have any child by default
  ($ignore_reason or $$reason = "Node can not have any child node.") and return 0 unless $self->can_have_child;

  #second filter - if invalid node
  ($ignore_reason or $$reason = "Node tried to append is invalid.") and return 0 unless defined $node && ref $node && $node->isa(__PACKAGE__);

  #third filter - if the node being appended as child is one of this node's ancestors
  my $ancestor = $self->parent_node;
  while (defined $ancestor) {
    ($ignore_reason or $$reason = "Node being appended is one of node's ancestors.") and return 0 if $ancestor->is_same_node($node);
    $ancestor = $ancestor->parent_node;
  }
  return 1;
}

sub append_child {
  ## Appends a child node (or creates a new child node before appending)
  ## @param New node (OR Hashref with keys - node_name (mandatory - can be 'text' for text nodes), inner_HTML/inner_text and other attributes if new element/text node is to be created)
  ## @return New node if success, undef otherwise
  ## Note: This method can also accept arguments as accepted by Dom::create_element if new element is to be created before appending it
  ## @example If $child_node is a Node itself
  ##    $node->append_child($child_node)
  ## @example If new node creation intended
  ##    $node->append_child('div')                                                                        - creates an empty <div> node and appends it to the $node
  ##    $node->append_child('text')                                                                       - creates an empty text node and appends it to the $node
  ##    $node->append_child({'node_name' => 'div', 'class' => 'narrow', 'inner_HTML' => 'this is a div'}) - creates a <div> node with given attributes and innerHTML
  ##    $node->append_child('div', {'class' => 'narrow', 'inner_HTML' => 'this is a div'})                - same as above
  ##    $node->append_child({'node_name' => 'text', 'text' => 'this is a text node'})                     - creates a text node with given text
  ##    $node->append_child('text', {'text' => 'this is a text node'})                                    - same as above
  ##    $node->append_child('text', 'this is a text node')                                                - same as above
  ## @exception DOMException as thrown by &_normalise_arguments or &_append_child
  my ($self, $child) = shift->_normalise_arguments(@_);
  return $self->_append_child($child);
}

sub append_children {
  ## Appends multiple children (wrapper around append_child)
  ## @param List (NOT ArrayRef) of nodes (or argument as accpeted by append child - only one argument per child - OR for multiple arguments per child, provide ref to the array of arguments)
  ## @return ArrayRef or List of newly appended nodes or undef indexed at any unsuccessful addition in the list
  ## @exception DOMException as thrown by &append_child
  my $self  = shift;
  my @nodes = map {$self->append_child(ref $_ eq 'ARRAY' ? @$_ : $_)} @_;
  return wantarray ? @nodes : \@nodes;
}

sub prepend_child {
  ## Appends a child node at the beginning (or also creates a new one before prepending)
  ## @params as accepted by append_child
  ## @return New node if success, undef otherwise
  ## @exception DOMException as thrown by &append_child or &insert_before
  my $self = shift;
  return $self->has_child_nodes
    ? $self->insert_before(@_, $self->first_child)
    : $self->append_child(@_);
}

sub insert_before {
  ## Appends a child node before a given reference node
  ## @params As accpeted by append_child
  ## @param  Reference node (mandatory)
  ## @return New Node object if successfully added, undef otherwise
  ## @exception DOMException as thrown by &_normalise_arguments or &_append_child or if reference node is invalid
  my $reference_node = pop @_;
  my ($self, $new_node) = shift->_normalise_arguments(@_);

  throw exception('DOMException', 'Reference node is missing')                         if not defined $reference_node;
  throw exception('DOMException', 'Reference node does not belong to the same parent') if !$self->is_same_node($reference_node->parent_node);
  throw exception('DOMException', 'Reference node is same as the new node')            if $reference_node->is_same_node($new_node);

  $self->_append_child($new_node);
  $new_node->previous_sibling->{'_next_sibling'} = 0;
  $new_node->{'_next_sibling'} = $reference_node;
  $new_node->{'_previous_sibling'} = $reference_node->previous_sibling || 0;
  $reference_node->previous_sibling->{'_next_sibling'} = $new_node if $reference_node->previous_sibling;
  $reference_node->{'_previous_sibling'} = $new_node;
  $self->_adjust_child_nodes;
  return $new_node;
}

sub insert_after {
  ## Appends a child node after a given reference node
  ## @params As accepted by insert_before
  ## @return New node if success, undef otherwise
  ## @exception DOMException as thrown by &append_child or &insert_before
  my $self = shift;
  my $reference_node = pop @_;

  return defined $reference_node->next_sibling
    ? $self->insert_before(@_, $reference_node->next_sibling)
    : $self->append_child(@_);
}

sub before {
  ## Places a new node before the node. An extra to DOM functionality to make it easy to insert nodes.
  ## @params As accepted by append_child
  ## @return New Node if success, undef otherwise
  ## @exception DOMException as thrown by &insert_before or if parent node not found
  my $self = shift;
  throw exception('DOMException', 'New node could not be inserted. Either the reference node is top level or has not been added to the DOM tree yet.') unless $self->parent_node;
  return $self->parent_node->insert_before(@_, $self);
}

sub after {
  ## Places a new node after the node. An extra to DOM functionality to make it easy to insert nodes.
  ## @param As accepted by append_child
  ## @return New Node if success, undef otherwise
   ## @exception DOMException as thrown by &insert_after or if parent node not found
  my $self = shift;
  throw exception('DOMException', 'New node could not be inserted. Either the reference node is top level or has not been added to the DOM tree yet.') unless $self->parent_node;
  return $self->parent_node->insert_after(@_, $self);
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
  ## @exception DOMException if node to be removed not found in the parent node
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
  throw exception('DOMException', 'Node to be removed was not found in the parent node.');
}

sub remove {
  ## Removes the child from it's parent node. An extra to DOM function to make it easy to remove nodes
  ## @return The node being removed itself
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
  ## @params As accepted by append_child
  ## @param Old Node
  ## @return Removed node
  ## @exception DOMException
  my $self = shift;
  my $old_node = pop @_;
  return $self->remove_child($old_node) if $self->insert_before(@_, $old_node);
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
  my ($self, $value) = @_;
  return encode_entities($value);
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
  return random_string(@_);
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
  push @$extras, 'html="'.$self->{'_text'}.'"' if $self->{'_text'} ne '';
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
  $val = substr $_, 1 and push @$extras, qq($val="$attr{$_}") for keys %attr;
  push @$extras, qq(flag:$_="$self->{'_flags'}{$_}") for keys %{$self->{'_flags'}};
  push @$extras, qq(element_type=).$self->element_type if $self->node_type == $self->ELEMENT_NODE;
  $string .= ' {'.join(', ', @$extras).'}';
  push @$output, $indent.$string;
  $_->dump($indent.'- ', $output) for @{$self->child_nodes};
  warn Data::Dumper->Dump([$output], ['_' x 10 . 'TREE' . '_' x 10]) if $do_warn;
}

sub _adjust_child_nodes {
  # private function used to adjust the array referenced at _child_nodes key after some changes in the child nodes
  # removes the 'just-removed' nodes from the array
  # re-arranges the array on the bases of linked list
  my $self = shift;
  return unless $self->has_child_nodes;   #has already no child nodes

  my $adjusted  = [];
  my $node;
  
  #avoid pointing initially to any removed node
  defined $_->parent_node and $self->is_same_node($_->parent_node) and $node = $_ and last for @{$self->{'_child_nodes'}};

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

sub _normalise_arguments {
  ## private method to normalise the arguments provided for methods append_child, insert_before etc
  ## @exception DOMException if node_name missing for any new node required to be created
  my ($self, $arg1, $arg2) = @_;

  # normalise the arguments
  ref $arg1 or $arg1 = { ($arg2 ? ref $arg2 ? %$arg2 : ($arg1 eq 'text' ? ('text' => $arg2) : ()) : ()), 'node_name' => $arg1 };

  # create new node if intended
  if (ref $arg1 eq 'HASH') {
    throw exception('DOMException', "Node can not be created: 'node_name' not provided for new node") unless exists $arg1->{'node_name'};
    $arg1 = $arg1->{'node_name'} eq 'text' ? $self->dom->create_text_node($arg1->{'text'}) : $self->dom->create_element(delete $arg1->{'node_name'}, $arg1);
  }
  return ($self, $arg1);
}

sub _append_child {
  ## private method to actually append the child
  ## this method is only called if arguments are normalised
  ## @exception DOMException if node is not &appendable
  my ($self, $child) = @_;

  my $reason = "";
  if ($self->appendable($child, \$reason)) {
    $self->{'_text'} = ''; #remove text if any
    $child->remove; #remove from present parent node, if any
    $child->{'_parent_node'} = $self;
    if ($self->has_child_nodes) {
      $child->{'_previous_sibling'} = $self->last_child;
      $self->last_child->{'_next_sibling'} = $child;
    }
    push @{$self->{'_child_nodes'}}, $child;
    return $child;
  }
  throw exception('DOMException', 'Node cannot be inserted at the specified point in the hierarchy. '.$reason);
}

1;