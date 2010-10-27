package EnsEMBL::Web::Form::Element::File;

use strict;
use warnings;

use base qw( EnsEMBL::Web::DOM::Node::Element::Input::File EnsEMBL::Web::Form::Element);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  $self->set_attribute('id',        $params->{'id'} || $self->unique_id);
  $self->set_attribute('name',      $params->{'name'})            if exists $params->{'name'};
  $self->set_attribute('class',     $params->{'class'})           if exists $params->{'class'};
  $self->set_attribute('class',     $self->CSS_CLASS_REQUIRED)    if exists $params->{'required'} && $params->{'required'} == 1;
  $self->disabled(1) if exists $params->{'disabled'} && $params->{'disabled'} == 1;
}

1;