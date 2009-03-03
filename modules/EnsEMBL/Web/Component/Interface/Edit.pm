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

  my $form = $self->data_form('edit', 'Preview');
  $form->add_element(
          'type'  => 'Hidden',
          'name'  => 'id',
          'value' => $object->param('id'),
        );

  ## Show creation/modification details?
  if ($object->interface->show_history) {
    my $history = $object->interface->history_fields($object->param('id'));
    foreach my $field (@$history) {
      $form->add_element(%$field);
    }
  }

  ## navigation elements
  $form->add_element( 'type' => 'Hidden', 'name' => '_referer', 'value' => $self->object->param('_referer'));
  $form->add_element( 'type' => 'Hidden', 'name' => 'x_requested_with', 'value' => $self->object->param('x_requested_with'));
  $form->add_element( 'type' => 'Submit', 'value' => 'Next');

  return $form->render;
}

1;
