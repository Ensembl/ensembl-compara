package EnsEMBL::Web::Component::Interface::SelectToDelete;

### Module to create generic data selection form for Document::Interface and its associated modules

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Interface);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return $self->object->interface->caption('select_to_delete') || 'Select a Record to Delete';
}

sub content {
  my $self = shift;

  my $form = $self->record_select($object, 'select');

  ## navigation elements
  $form->add_element( 'type' => 'Hidden', 'name' => 'db_action', 'value' => 'delete');
  $form->add_element( 'type' => 'Hidden', 'name' => 'dataview', 'value' => 'preview');
  $form->add_element( 'type' => 'Submit', 'value' => 'Next');

  return $form->render;
}

1;
