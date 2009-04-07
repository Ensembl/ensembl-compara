package EnsEMBL::Web::Component::Help::Preview;

## This is an anti-spam measure - it should stymie robots, and by switching field names
## between the 'honeypot' ones in the form and the real ones, should stop the rest :)

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

  my $form = EnsEMBL::Web::Form->new( 'contact', "/Help/SendEmail", 'post' );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Your name',
    'value'   => $object->param('name'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'name',
    'value'   => $object->param('name'),
  );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Your email',
    'value'   => $object->param('address'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'email',
    'value'   => $object->param('address'),
  );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Subject',
    'value'   => $object->param('subject'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'subject',
    'value'   => $object->param('subject'),
  );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Message',
    'value'   => $object->param('text'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'message',
    'value'   => $object->param('text'),
  );

  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'string',
    'value'   => $object->param('string'),
  );

  $form->add_element(
    'type'    => 'Hidden',
    'name'    => '_referer',
    'value'   => $object->param('_referer'),
  );

  ## Pass honeypot fields, to weed out any persistent robots!
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'honeypot_1',
    'value'   => $object->param('email'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'honeypot_2',
    'value'   => $object->param('comments'),
  );

  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Send Email',
  );

  return $form->render;
}

1;
