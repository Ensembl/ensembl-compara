package EnsEMBL::Web::Form::Element::NoEdit;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Div
  EnsEMBL::Web::Form::Element
);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  $params->{'caption'} = $params->{'value'} unless exists $params->{'caption'};
  
  $self->append_child($self->dom->create_element($params->{'is_html'} ? 'div' : 'span', {($params->{'is_html'} ? 'inner_HTML' : 'inner_text') => $params->{'caption'}}));

  $self->set_attribute('id',    $params->{'wrapper_id'})    if exists $params->{'wrapper_id'};
  $self->set_attribute('class', $params->{'wrapper_class'}) if exists $params->{'wrapper_class'};

  return if $params->{'no_input'};

  $params->{'value'} = $self->encode_htmlentities($params->{'value'}) unless $params->{'is_encoded'};

  my $input = $self->append_child($self->dom->create_element('inputhidden'));
  exists $params->{$_} and $input->set_attribute($_, $params->{$_}) for qw(id name class value);
}

sub caption {
  ## Sets/gets caption for the noedit element
  my $self = shift;

  @_ and $self->first_child->inner_HTML(@_);  
  return $self->first_child->inner_HTML;
}

1;