package EnsEMBL::Web::DOM::Node::Element::Select;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'select';
}

sub allowed_attributes {
  ## @overrides
  return [ @{ shift->SUPER::allowed_attributes }, qw(name value type accesskey tabindex multiple disabled size) ];
}

sub form {
  ## Returns a reference to the form object that contains the select
  my $self = shift;
  my $node = $self;
  while ($node) {
    $node = $node->parent_node;
    return $node if defined $node && $node->node_name eq 'form';
  }
  return undef;
}

sub selected_index {
  ## Sets or returns the index of the selected option in a dropdown list
  ## If the dropdown list allows multiple selections it will only return the index of the first option selected
  ## If invalid index, unselects all and returns -1
  ## If not selected any and argument missing, returns -1
  ## Useless for multiple select (so don't use there)
  my $self = shift;
  my $index = @_ ? shift : -1;
  my $i = 0;
  for (@{ $self->options }) {
    if ($index == -1) {
      return $i++ if $_->selected == $i;
    }
    else {
      $_->selected($i++ == $index ? '1' : '0');
    }
  }
  return $index;
}

sub options {
  ## Getter of all the option element objects of the select
  my $self = shift;
  my $option = __PACKAGE__;
  $option =~ s/Select$/Option/;
  (my $optgroup = $option) =~ s/Option$/Optgroup/;
  
  my $options = [];
  for (@{ $self->{'_child_nodes'} }) {
    push @{ $options }, $_ if ($_->isa($option));
    push @{ $options }, @{ $_->{'_child_nodes'} } if ($_->isa($optgroup));
  }
  return $options;
}

sub add {
  ## Adds an option object to the select object
  ## Alias for append_child/insert_before
  my $self = shift;
  my $option = shift;
  return $self->insert_before($option, shift) if @_;
  return $self->append_child($option);
}

sub remove {
  ## Removes a option object from select object
  my ($self, $option) = shift;
  return $option->parent_node->remove_child($option);
}

sub disabled {
  ## Accessor for disabled attribute
  return shift->_access_attribute('disabled', @_);
}

sub multiple {
  ## Accessor for multiple attribute
  return shift->_access_attribute('multiple', @_);
}

sub validate_attribute {
  ## @overrides
  my ($self, $attrib_ref, $value_ref) = @_;
  
  if ($$attrib_ref eq 'disabled') {
    $$value_ref = 'disabled';
  }
  elsif ($$attrib_ref eq 'multiple') {
    $$value_ref = 'multiple';
  }
  return $self->SUPER::validate_attribute($attrib_ref, $value_ref);
}

sub _appendable {
  ## @overrides
  my ($self, $child) = @_;
  return $child->node_name =~ /^(option|optgroup)$/ ? 1 : 0;
}

1;