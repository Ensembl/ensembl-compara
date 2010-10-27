package EnsEMBL::Web::DOM::Node::Element::Fieldset;

## Status - Under Development

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'fieldset';
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

#sub validate_attribute {}
#sub allowed_attributes {}
#sub mandatory_attributes {}
#sub can_have_child {}
#sub allowed_child_nodes {}
#sub appendable {}

1;