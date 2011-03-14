package EnsEMBL::Web::Component::Help::Contact;

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

  my $self  = shift;
  my $hub   = $self->hub;

  my $form      = $self->new_form({'id' => 'contact', 'action' => "/Help/Preview", 'method' => 'post'});
  my $fieldset  = $form->add_fieldset;

  if ($hub->param('strong')) {
    $fieldset->add_notes(sprintf('Sorry, no pages were found containing the term <strong>%s</strong> (or more than 50% of articles contain this term).
                        Please <a href="/Help/Search">try again</a> or use the form below to contact HelpDesk:', $hub->param('kw')));
  }
  
  $fieldset->add_field([{
    'type'    => 'String',
    'name'    => 'name',
    'label'   => 'Your name',
    'value'   => $hub->param('name'),
  }, {
    'type'    => 'Honeypot',
    'name'    => 'email',
    'label'   => 'Address',
  }, {
    'type'    => 'Email',
    'name'    => 'address',
    'label'   => 'Your Email',
    'value'   => $hub->param('address'),
  }, {
    'type'    => 'String',
    'name'    => 'subject',
    'label'   => 'Subject',
    'value'   => $hub->param('subject'),
  }, {
    'type'    => 'Honeypot',
    'name'    => 'comments',
    'label'   => 'Comments',
  }, {
    'type'    => 'Text',
    'name'    => 'message',
    'label'   => 'Message',
    'value'   => $hub->param('message'),
  }]);
  
  $fieldset->add_hidden({
    'name'    => 'string',
    'value'   => $hub->param('string'),
  });

  $fieldset->add_button({
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Preview',
  });

  return $form->render;
}

1;
