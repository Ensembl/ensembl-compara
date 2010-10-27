package EnsEMBL::Web::DOM::Node::Element::Img;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'img';
}

sub can_have_child {
  ## @overrides
  return 0;
}

sub mandatory_attribites {
  ## @overrides
  return ['alt', 'src'];
}

sub allowed_attributes {
  ## @overrides
  return [ @{ shift->SUPER::allowed_attributes }, qw(height longdesc lowsrc usemap width) ];
}

#sub validate_attribute {}

1;
