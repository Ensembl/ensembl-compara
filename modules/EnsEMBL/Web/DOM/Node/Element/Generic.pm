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

1;