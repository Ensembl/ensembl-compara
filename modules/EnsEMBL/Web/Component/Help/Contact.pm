package EnsEMBL::Web::Component::Help::Contact;

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

  my $form = EnsEMBL::Web::Form->new( 'contact', "/Help/Preview", 'post' );

  if ($object->param('strong')) {
    $form->add_element(
      'type' => 'Information',
      'value' => 'Sorry, no pages were found containing the term <strong>'.$object->param('kw')
                  .qq#</strong> (or more than 50% of articles contain this term). Please
<a href="/Help/Search">try again</a> or use the form below to contact HelpDesk:#,
    );
  }

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

  $form->add_element(
    'type'    => 'String',
    'name'    => 'subject',
    'label'   => 'Subject',
  );

 $form->add_element(
    'type'    => 'Honeypot',
    'name'    => 'comments',
    'label'   => 'Comments',
  );

 $form->add_element(
    'type'    => 'Text',
    'name'    => 'text',
    'label'   => 'Message',
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

  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Preview',
  );

  return $form->render;
}

1;
