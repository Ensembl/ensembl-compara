package EnsEMBL::Web::Component::Interface::ConfirmDelete;

### Module to create confirmation form for  Document::Interface and its associated modules

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
  return $self->object->interface->caption('confirm_delete') || 'Confirm Deletion';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = EnsEMBL::Web::Form->new('confirm', '/'.$self->script_name.'/Delete', 'post');;

  ## navigation elements
  $form->add_element( 'type' => 'Information', 'value' => 'Are you sure you want to delete this group?');
  $form->add_element( 'type' => 'Hidden', 'name' => 'id', 'value' => $object->param('id'));
  $form->add_element( 'type' => 'Hidden', 'name' => '_referer', 'value' => $self->object->param('_referer'));
  $form->add_element( 'type' => 'Hidden', 'name' => 'x_requested_with', 'value' => $self->object->param('x_requested_with'));
  $form->add_element( 'type' => 'Submit', 'value' => 'Delete');

  return $form->render;
}

1;
