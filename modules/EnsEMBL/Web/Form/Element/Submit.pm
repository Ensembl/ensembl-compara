package EnsEMBL::Web::Form::Element::Submit;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Input::Submit
  EnsEMBL::Web::Form::Element
);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  exists $params->{$_} and $self->set_attribute($_, $params->{$_}) for qw(id name value class);
  $self->disabled(1) if $params->{'disabled'};
}

1;