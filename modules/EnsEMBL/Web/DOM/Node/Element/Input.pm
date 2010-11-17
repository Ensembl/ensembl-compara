package EnsEMBL::Web::DOM::Node::Element::Input;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'input';
}

sub can_have_child {
  ## @overrides
  return 0;
}

sub form {
  ## Returns a reference to the form object that contains the input
  my $self = shift;
  my $node = $self;
  while ($node) {
    $node = $node->parent_node;
    return $node if defined $node && $node->node_name eq 'form';
  }
  return undef;
}

sub disabled {
  ## Accessor for disabled attribute
  return shift->_access_attribute('disabled', @_);
}

1;