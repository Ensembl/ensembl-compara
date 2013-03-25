package EnsEMBL::Web::Component::Help::FeedbackPreview;

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

  my $form  = $self->new_form({'id' => 'contact', 'action' => {'type' => 'Help', 'action' => 'MovieEmail'}, 'method' => 'post'});

  $form->add_field({
    'type'    => 'noedit',
    'label'   => 'Subject',
    'name'    => 'subject',
    'value'   => 'Feedback for Ensembl tutorial movies',
  });

  $form->add_field({
    'type'    => 'noedit',
    'label'   => 'Movie title',
    'name'    => 'title',
    'value'   => $hub->param('title'),
  });

  $form->add_field({
    'type'    => 'noedit',
    'label'   => 'Your name',
    'name'    => 'name',
    'value'   => $hub->param('name'),
  });

  $form->add_field({
    'type'    => 'noedit',
    'label'   => 'Your email',
    'name'    => 'address',
    'value'   => $hub->param('address'),
  });

  my %problems = map { $_->{'value'} => $_->{'caption'} } @{$self->object->movie_problems};
  my @problems = $hub->param('problem');

  $form->add_field({
    'type'      => 'noedit',
    'no_input'  => 1,
    'is_html'   => 1,
    'value'     => @problems ? sprintf('<ul>%s</ul>', join('', map { "<li>$problems{$_}</li>" } @problems)) : '',
  });

  $form->add_hidden({'name' => 'problem', 'value' => $_}) for @problems;

  $form->add_field({
    'type'    => 'noedit',
    'label'   => 'Additional comments',
    'name'    => 'text',
    'value'   => $hub->param('text'),
  });

  ## Pass honeypot fields, to weed out any persistent robots!
  $form->add_hidden({'name' => 'honeypot_1', 'value' => $hub->param('email')});
  $form->add_hidden({'name' => 'honeypot_2', 'value' => $hub->param('comments')});

  $form->add_button({
    'name'    => 'submit',
    'value'   => 'Send email',
  });

  return $form->render;
}

1;
