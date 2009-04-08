package EnsEMBL::Web::Component::Help::MovieFeedback;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use EnsEMBL::Web::Form;
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = EnsEMBL::Web::Form->new( 'contact', "/Help/FeedbackPreview", 'post' );

  $form->add_element(
    'type'    => 'NoEdit',
    'name'    => 'subject',
    'label'   => 'Subject',
    'value'   => 'Feedback for Ensembl tutorial movies',
  );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Movie title',
    'value'   => $object->param('title'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'title',
    'value'   => $object->param('title'),
  );

  $form->add_element(
    'type'    => 'String',
    'name'    => 'name',
    'label'   => 'Your name',
  );

  $form->add_element(
    'type'    => 'Honeypot',
    'name'    => 'email',
    'label'   => 'Address',
  );

  $form->add_element(
    'type'    => 'Email',
    'name'    => 'address',
    'label'   => 'Your Email',
  );

  my $problems = [
    {'value' => 'no_load',   'name' => 'Movie did not appear'},
    {'value' => 'playback',  'name' => 'Playback was jerky'},
    {'value' => 'no_sound',  'name' => 'No sound'},
    {'value' => 'bad_sound', 'name' => 'Poor quality sound'},
    {'value' => 'other',     'name' => 'Other (please describe below)'},
  ];
  
  $form->add_element(
    'type'    => 'MultiSelect',
    'name'    => 'problem',
    'label'   => 'Problem(s)',
    'values'  => $problems,
  );

 $form->add_element(
    'type'    => 'Text',
    'name'    => 'text',
    'label'   => 'Additional comments',
  );

 $form->add_element(
    'type'    => 'Honeypot',
    'name'    => 'comments',
    'label'   => 'Message',
  );

  $form->add_element(
    'type'    => 'Hidden',
    'name'    => '_referer',
    'value'   => $object->param('_referer'),
  );

  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Preview',
  );

  return $form->render;
}

1;
