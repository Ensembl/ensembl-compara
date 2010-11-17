package EnsEMBL::Web::DOM::Node::Element::Fieldset;

use strict;

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

1;