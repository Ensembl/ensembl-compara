package EnsEMBL::Web::Component::Help::Preview;

## This is an anti-spam measure - it should stymie robots, and by switching field names
## between the 'honeypot' ones in the form and the real ones, should stop the rest :)

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $form = $self->new_form({'id' =>'contact', 'action' => "/Help/SendEmail", 'method' => 'post'});
  my $fieldset = $form->add_fieldset;
  
  $fieldset->add_field([{
    'type'    => 'NoEdit',
    'name'    => 'name',
    'label'   => 'Your name',
    'value'   => $hub->param('name'),
  },{
    'type'    => 'NoEdit',
    'name'    => 'address',
    'label'   => 'Your email',
    'value'   => $hub->param('address'),
  },{
    'type'    => 'NoEdit',
    'name'    => 'subject',
    'label'   => 'Subject',
    'value'   => $hub->param('subject'),
  },{
    'type'    => 'NoEdit',
    'name'    => 'message',
    'label'   => 'Message',
    'value'   => $hub->param('message'),
  }]);

  $fieldset->add_hidden([{
    'name'    => 'string',
    'value'   => $hub->param('string'),
  },{
    'name'    => 'honeypot_1',
    'value'   => $hub->param('email'),
  },{
    'name'    => 'honeypot_2',
    'value'   => $hub->param('comments'),
  }]);


  $form->add_button({
    'buttons' => [{
      'type'    => 'Submit',
      'name'    => 'submit',
      'value'   => 'Back',
    },{
      'type'    => 'Submit',
      'name'    => 'submit',
      'value'   => 'Send Email',
    }]
  });

  return $form->render;
}

1;
