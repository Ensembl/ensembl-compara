package EnsEMBL::Web::Form::Element::String;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Input::Text
  EnsEMBL::Web::Form::Element
);

use constant {
  VALIDATION_CLASS =>  '_string', #override in child classes
};

sub render {
  ## @overrides
  my $self = shift;
  $self->parent_node->insert_after($self->dom->create_element('span', {'inner_HTML' => ' '.$self->{'__shortnote'}}), $self);
    if exists $self->{'__shortnote'};
  return $self->SUPER::render;
};

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  $self->set_attribute('id',        $params->{'id'})              if exists $params->{'id'};
  $self->set_attribute('name',      $params->{'name'})            if exists $params->{'name'};
  $self->set_attribute('value',     $params->{'value'})           if exists $params->{'value'};
  $self->set_attribute('size',      $params->{'size'})            if exists $params->{'size'};
  $self->set_attribute('class',     $params->{'class'})           if exists $params->{'class'};
  $self->set_attribute('class',     $self->VALIDATION_CLASS)      if $self->VALIDATION_CLASS ne '';
  $self->set_attribute('maxlength', $params->{'maxlength'})       if exists $params->{'maxlength'} && $params->{'maxlength'} != 0;

  $self->disabled(1) if exists $params->{'disabled'} && $params->{'disabled'} == 1;
  $self->readonly(1) if exists $params->{'readonly'} && $params->{'readonly'} == 1;
  
  if (exists $params->{'required'}) {
    $self->set_attribute('class', $self->CSS_CLASS_REQUIRED);
    $params->{'shortnote'} ||= '';
    $params->{'shortnote'} = '<strong title="Required field">*</strong> '.$params->{'shortnote'};
  }
  else {
    $self->set_attribute('class', $self->CSS_CLASS_OPTIONAL);
  }
  $self->{'__shortnote'} = $params->{'shortnote'} if exists $params->{'shortnote'};
}

1;