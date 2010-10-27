package EnsEMBL::Web::Form::Element::Text;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw( EnsEMBL::Web::DOM::Node::Element::Input::Text EnsEMBL::Web::Form::Element);

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  $self->set_attribute('id',        $params->{'id'} || $self->unique_id);
  $self->set_attribute('name',      $params->{'name'})            if exists $params->{'name'};
  $self->set_attribute('value',     $params->{'value'})           if exists $params->{'value'};
  $self->set_attribute('size',      $params->{'size'})            if exists $params->{'size'};
  $self->set_attribute('class',     $params->{'class'})           if exists $params->{'class'};
  $self->set_attribute('class',     $self->CSS_CLASS_REQUIRED)    if exists $params->{'required'} && $params->{'required'} == 1;
  $self->set_attribute('maxlength', $params->{'maxlength'})       if exists $params->{'maxlength'} && $params->{'maxlength'} != 0;
  $self->set_attribute('class',     $self->validation_types->{ $params->{'validate_as'} })
    if exists $params->{'validate_as'} && $params->{'validate_as'} && exists $self->validation_types->{ $params->{'validate_as'} };
  $self->set_attribute('class',     $self->CSS_CLASS_PREFIX_MAX_VALIDATION.$params->{'max'})
    if exists $params->{'max'}; 
  $self->disabled(1) if exists $params->{'disabled'} && $params->{'disabled'} == 1;
  $self->readonly(1) if exists $params->{'readonly'} && $params->{'readonly'} == 1;

  if (exists $params->{'required'} && $params->{'required'} == 1) {
    $params->{'shortnote'} = ' *' unless exists $params->{'shortnote'};
  }

  if (exists $params->{'shortnote'}) {
    $self->parent_node->append_child($self->dom->create_element('span'));
    $self->next_sibling->inner_text($params->{'shortnote'});
  }
}

1;