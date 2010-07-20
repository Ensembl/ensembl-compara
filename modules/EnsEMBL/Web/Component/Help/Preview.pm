package EnsEMBL::Web::Component::Help::Preview;

## This is an anti-spam measure - it should stymie robots, and by switching field names
## between the 'honeypot' ones in the form and the real ones, should stop the rest :)

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->model->hub;

  my $form = EnsEMBL::Web::Form->new( 'contact', "/Help/SendEmail", 'post' );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Your name',
    'value'   => $hub->param('name'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'name',
    'value'   => $hub->param('name'),
  );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Your email',
    'value'   => $hub->param('address'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'address',
    'value'   => $hub->param('address'),
  );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Subject',
    'value'   => $hub->param('subject'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'subject',
    'value'   => $hub->param('subject'),
  );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Message',
    'value'   => $hub->param('message'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'message',
    'value'   => $hub->param('message'),
  );

  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'string',
    'value'   => $hub->param('string'),
  );

  ## Pass honeypot fields, to weed out any persistent robots!
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'honeypot_1',
    'value'   => $hub->param('email'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'honeypot_2',
    'value'   => $hub->param('comments'),
  );

  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Back',
  );
  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Send Email',
  );

  return $form->render;
}

1;
