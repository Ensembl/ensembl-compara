package EnsEMBL::Web::Form::Element::Textarea;

use strict;
use warnings;

use base qw( EnsEMBL::Web::DOM::Node::Element::Textarea EnsEMBL::Web::Form::Element);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  $self->set_attribute('id',        $params->{'id'} || $self->unique_id);
  $self->set_attribute('name',      $params->{'name'})            if exists $params->{'name'};
  $self->set_attribute('rows',      $params->{'rows'})            if exists $params->{'rows'};
  $self->set_attribute('cols',      $params->{'cols'})            if exists $params->{'cols'};
  $self->set_attribute('class',     $params->{'class'})           if exists $params->{'class'};
  $self->set_attribute('class',     $self->CSS_CLASS_REQUIRED)    if exists $params->{'required'} && $params->{'required'} == 1;
  $self->set_attribute('class',     $self->validation_types->{ $params->{'validate_as'} })
    if $params->{'validate_as'} && exists $self->validation_types->{ $params->{'validate_as'} };
  $self->set_attribute('class',     $self->CSS_CLASS_PREFIX_MAX_VALIDATION.$params->{'max'})
    if exists $params->{'max'}; 
  $self->disabled(1) if exists $params->{'disabled'} && $params->{'disabled'} == 1;
  $self->readonly(1) if exists $params->{'readonly'} && $params->{'readonly'} == 1;
  $self->inner_HTML($params->{'value'}) if exists $params->{'value'};
  
  if (exists $params->{'shortnote'}) {
    $self->parent_node->append_child($self->dom->create_element('span'));
    $self->next_sibling->inner_text($params->{'shortnote'});
  }
}

1;