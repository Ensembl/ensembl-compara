package EnsEMBL::Web::Component::Interface::Edit;

### Module to create generic data modification form for Document::Interface and its associated modules

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
  return $self->object->interface->caption('edit') || 'Edit this Record';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my ($primary_key) = $object->interface->data->primary_columns;
  my $id = $object->param($primary_key) || $object->param('id');

  my $form = $self->data_form($object, $object, 'edit');
  $form->add_element(
          'type'  => 'Hidden',
          'name'  => $primary_key,
          'value' => $id,
        );
  $form->add_element(
          'type'  => 'Hidden',
          'name'  => 'mode',
          'value' => 'edit',
        );

  ## Show creation/modification details?
  if ($object->interface->show_history) {
    my $history = $object->interface->history_fields($id);
    foreach my $field (@$history) {
      $form->add_element(%$field);
    }
  }

  ## navigation elements
  $form->add_element( 'type' => 'Hidden', 'name' => 'db_action', 'value' => 'save');
  $form->add_element( 'type' => 'Hidden', 'name' => 'dataview', 'value' => 'preview');
  $form->add_element( 'type' => 'Submit', 'value' => 'Next');

  return $form->render;
}

1;
