package EnsEMBL::Web::Component::UserData::RenameRecord;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return '';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = EnsEMBL::Web::Form->new('rename_record', '/'.$self->object->data_species.'/UserData/SaveRecord', 'post');

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $method = $object->param('accessor');
  my ($record) = $user->$method($object->param('id'));
  return unless $record;

  $form->add_element(
    'type'  => 'String',
    'name'  => 'name',
    'label' => 'Name',
    'value' => $record->name,
  );
  $form->add_element(
    'type'  => 'Hidden',
    'name'  =>  'id',
    'value' => $object->param('id'),
  );
  $form->add_element(
    'type'  => 'Hidden',
    'name'  =>  'accessor',
    'value' => $object->param('accessor'),
  );

  ## navigation elements
  $form->add_element( 'type' => 'Hidden', 'name' => '_referer', 'value' => $self->object->param('_referer'));
  $form->add_element( 'type' => 'Hidden', 'name' => 'x_requested_with', 'value' => $self->object->param('x_requested_with'));
  $form->add_element( 'type' => 'Submit', 'value' => 'Save');

  return $form->render;
}

1;
