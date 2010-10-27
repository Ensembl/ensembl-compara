package EnsEMBL::Web::DOM::Node::Element::Input::Image;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'image');
  return $self;
}

sub allowed_attributes {
  ## @overrides
  return [ @{ shift->SUPER::allowed_attributes }, qw(alt src) ];
}

1;