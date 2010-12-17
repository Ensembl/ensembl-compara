package EnsEMBL::Web::Form::Element::NoEdit;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Div
  EnsEMBL::Web::Form::Element
);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  $self->append_child($self->dom->create_text_node($params->{'value'}));
  $self->set_attribute('id',    $params->{'wrapper_id'})    if exists $params->{'wrapper_id'};
  $self->set_attribute('class', $params->{'wrapper_class'}) if exists $params->{'wrapper_class'};

  return if $params->{'no_input'};
  
  my $input = $self->append_child($self->dom->create_element('inputhidden'));
  exists $params->{$_} and $input->set_attribute($_, $params->{$_}) for qw(id name class value); 
}

1;