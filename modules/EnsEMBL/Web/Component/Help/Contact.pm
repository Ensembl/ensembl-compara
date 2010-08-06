package EnsEMBL::Web::Component::Help::Contact;

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
  my $hub = $self->hub;

  my $form = EnsEMBL::Web::Form->new( 'contact', "/Help/Preview", 'post' );

  if ($hub->param('strong')) {
    $form->add_element(
      'type' => 'Information',
      'value' => 'Sorry, no pages were found containing the term <strong>'.$hub->param('kw')
                  .qq#</strong> (or more than 50% of articles contain this term). Please
<a href="/Help/Search">try again</a> or use the form below to contact HelpDesk:#,
    );
  }

  $form->add_element(
    'type'    => 'String',
    'name'    => 'name',
    'label'   => 'Your name',
    'value'   => $hub->param('name'),
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
    'value'   => $hub->param('address'),
  );

  $form->add_element(
    'type'    => 'String',
    'name'    => 'subject',
    'label'   => 'Subject',
    'value'   => $hub->param('subject'),
  );

 $form->add_element(
    'type'    => 'Honeypot',
    'name'    => 'comments',
    'label'   => 'Comments',
  );

 $form->add_element(
    'type'    => 'Text',
    'name'    => 'message',
    'label'   => 'Message',
    'value'   => $hub->param('message'),
  );

  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'string',
    'value'   => $hub->param('string'),
  );

  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Preview',
  );

  return $form->render;
}

1;
