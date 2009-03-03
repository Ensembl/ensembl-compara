package EnsEMBL::Web::Component::Interface::Preview;

### Module to create generic data preview form for Document::Interface and its associated modules

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
  return $self->object->interface->caption('preview') || 'Preview';
}

sub content {
### Displays a record or form input as non-editable text,
### and also passes the data as hidden form elements
  my $self = shift;
  my $object = $self->object;

  ## Create form
  my $function = 'Save';
  my $url = '/'.$ENV{'ENSEMBL_SPECIES'};
  $url = '' if $url !~ /_/;
  $url = '/'.$object->interface->script_name.'/'.$function;
  my $form = EnsEMBL::Web::Form->new('preview', $url, 'post');

  ## get data and assemble form
  my ($primary_key) = $object->interface->data->primary_columns;
  my $id = $object->param($primary_key) || $object->param('id');
  my $db_action = $object->param('db_action');
  if ($object->param('owner_type')) {
    #$object->interface->data->attach_owner($object->param('owner_type'));
  }

  if ($db_action eq 'delete') {
    #$object->interface->data->populate($id);
  } else {
    $object->interface->cgi_populate($object);
  }

  $form->add_element(
    'type'  => 'Hidden',
    'name'  => 'id',
    'value' => $id,
  );

  my $preview_fields = $object->interface->preview_fields($id, $object);
  my $element;
  foreach $element (@$preview_fields) {
    $form->add_element(%$element);
  }
  my $pass_fields = $object->interface->pass_fields($id);
  foreach $element (@$pass_fields) {
    $form->add_element(%$element);
  }

  ## navigation elements
  $form->add_element( 'type' => 'Hidden', 'name' => '_referer', 'value' => $object->param('_referer'));
  $form->add_element( 'type' => 'Hidden', 'name' => 'x_requested_with', 'value' => $object->param('x_requested_with'));
  $form->add_element( 'type' => 'Submit', 'value' => $function );


  return $form->render;
}

1;
