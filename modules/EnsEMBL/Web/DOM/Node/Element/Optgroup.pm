package EnsEMBL::Web::DOM::Node::Element::Optgroup;

## Status - Under Development

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'optgroup';
}

sub allowed_child_nodes {
  ## @overrides
  return ['option'];
}

sub allowed_attributes {
  ## @overrides
  return [ @{ shift->SUPER::allowed_attributes }, "label" ];
}

1;