package EnsEMBL::Web::Component::UserData::UploadFeedback;

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
  return 'File Uploaded';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = EnsEMBL::Web::Form->new('upload_feedback', '', 'post');

  ## Set format if coming via more_input
  if ($self->object->param('format')) {
    $self->object->get_session->set_data(
      type   => 'upload',
      code   => $self->object->param('code'),
      format => $self->object->param('format'),
    );
  }

  $form->add_element(type => 'Information', value => qq(Thank you - your file was successfully uploaded. Close this Control Panel to view your data));
  $form->add_element(type => 'Hidden', name => 'md5', value => $self->object->param('md5'));
  $form->add_element(type => 'ForceReload' );

  return $form->render;
}

1;
