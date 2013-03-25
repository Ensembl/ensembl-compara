package EnsEMBL::Web::Component::Help::MovieFeedback;

use strict;
use warnings;

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
  my $form  = $self->new_form({'id' => 'contact', 'action' => {qw(type Help action FeedbackPreview)}, 'method' => 'post'});

  $form->add_field({
    'type'        => 'noedit',
    'name'        => 'subject',
    'label'       => 'Subject',
    'value'       => 'Feedback for Ensembl tutorial movies',
  });

  $form->add_field({
    'type'        => 'noedit',
    'label'       => 'Movie title',
    'name'        => 'title',
    'value'       => $hub->param('title'),
  });

  $form->add_field({
    'type'        => 'string',
    'name'        => 'name',
    'label'       => 'Your name',
  });

  $form->add_field({
    'type'        => 'honeypot',
    'name'        => 'email',
    'label'       => 'Address',
  });

  $form->add_field({
    'type'        => 'email',
    'name'        => 'address',
    'label'       => 'Your Email',
  });

  $form->add_field({
    'type'        => 'dropdown',
    'name'        => 'problem',
    'label'       => 'Problem(s)',
    'values'      => $self->object->movie_problems,
    'multiple'    => 1
  });

 $form->add_field({
    'type'        => 'text',
    'name'        => 'text',
    'label'       => 'Additional comments',
  });

 $form->add_field({
    'type'        => 'honeypot',
    'name'        => 'comments',
    'label'       => 'Message',
  });

  $form->add_button({
    'value'       => 'Preview'
  });

  return $form->render;
}

1;
