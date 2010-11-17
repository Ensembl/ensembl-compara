package EnsEMBL::Web::DOM::Node::Element::Span;

## Status - Under Development

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'span';
}

sub _appendable {
  ## @overrides
  my ($self, $child) = @_;
  return 
    $child->node_type == $self->TEXT_NODE
    ||
    $child->node_type == $self->COMMENT_NODE
    ||
    $child->node_type == $self->ELEMENT_NODE
      &&
      $child->node_name =~ /^(a|button|img|input|label|select|span|textarea)$/
    ? 1
    : 0
  ;
}

1;