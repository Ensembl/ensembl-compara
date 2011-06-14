package EnsEMBL::Web::DOM::Node::Element::Generic;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->{'_node_name'} = 'div';#default
  return $self;
}

sub node_name :lvalue {
  ## @overrides
  $_[0]->{'_node_name'};
}

sub clone_node {
  ## @overrides
  ## Copies node name for the new clone
  my $self  = shift;
  my $clone = $self->SUPER::clone_node(@_);
  $clone->{'_node_name'} = $self->{'_node_name'};
  return $clone;
}

1;