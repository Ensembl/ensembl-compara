package EnsEMBL::Web::DOM::Node::Element::Dynamic;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->{'dynamic_node_name'} = 'div';#default
  return $self;
}

sub node_name :lvalue {
  ## @overrides
  $_[0]->{'dynamic_node_name'};
}

1;