package EnsEMBL::Web::Form::Element::NoEdit;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Div
  EnsEMBL::Web::Form::Element
);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  my $value = exists $params->{'value'} && defined $params->{'value'} ? $params->{'value'} : ''; 
  my $text = $self->dom->create_text_node;

  $text->text($value);
  my $input = $self->dom->create_element('inputhidden');
  $input->set_attribute('id',     $params->{'id'})     if exists $params->{'id'};
  $input->set_attribute('name',   $params->{'name'})   if exists $params->{'name'};
  $input->set_attribute('class',  $params->{'class'})  if exists $params->{'class'};
  $input->set_attribute('value',  $value);
  
  $self->append_child($text);
  $self->append_child($input);
}

1;