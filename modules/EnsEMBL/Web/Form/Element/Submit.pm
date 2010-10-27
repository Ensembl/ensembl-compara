package EnsEMBL::Web::Form::Element::Submit;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw( EnsEMBL::Web::DOM::Node::Element::Input::Submit EnsEMBL::Web::Form::Element);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  $self->set_attribute('id',        $params->{'id'} || $self->unique_id);
  $self->set_attribute('name',      $params->{'name'})            if exists $params->{'name'};
  $self->set_attribute('value',     $params->{'value'})           if exists $params->{'value'};
  $self->set_attribute('class',     $params->{'class'})           if exists $params->{'class'};
  $self->disabled(1) if exists $params->{'disabled'} && $params->{'disabled'} == 1;
}

1;