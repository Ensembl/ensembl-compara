package EnsEMBL::Web::Component::UserData::TempDasSaved;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Sources Saved';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = $self->modal_form('ok_tempdas', '');

  if ($self->object->param('source')) {
    $form->add_element('type'=>'Information', 'value' => 'The DAS source details were saved to your user account.');
  }

  if ($self->object->param('url')) {
    $form->add_element('type'=>'Information', 'value' => 'The data URL was saved to your user account.');
  }
  $form->add_element('type'=>'Information', 'value' => "Click on 'Manage Data' in the lefthand menu to see all your saved URLs and DAS sources");

  $form->add_element( 'type' => 'ForceReload' );

  return $form->render;
}

1;
