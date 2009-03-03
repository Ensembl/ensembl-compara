package EnsEMBL::Web::Component::Interface::Display;

### Module to create generic data display for Interface and its associated modules

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
  return $self->object->interface->caption('display') || 'Record';
}

sub content {
### Displays a record or form input as non-editable text,
### and also passes the data as hidden form elements
  my $self = shift;
  my $object = $self->object;

  ## Use form code for easy, uniform layout and easy linking to edit function
  my $url = '/'.$ENV{'ENSEMBL_SPECIES'};
  $url = '' if $url !~ /_/;
  $url = '/'.$self->script_name.'/Edit';

  my $form = EnsEMBL::Web::Form->new('display', $url, 'post');

  my ($primary_key) = $object->interface->data->primary_columns;
  my $id = $object->param($primary_key) || $object->param('id');
  my $preview_fields = $object->interface->preview_fields($id, $object);
  my $element;
  foreach $element (@$preview_fields) {
    $form->add_element(%$element);
  }

  $form->add_element( 'type' => 'Hidden', 'name'  => 'id', 'value' => $object->param('id'));
  $form->add_element( 'type' => 'Hidden', 'name' => '_referer', 'value' => $self->object->param('_referer'));
  $form->add_element( 'type' => 'Hidden', 'name' => 'x_requested_with', 'value' => $self->object->param('x_requested_with'));
  $form->add_element( 'type' => 'Submit', 'value' => 'Edit');

  return $form->render;
}

1;
