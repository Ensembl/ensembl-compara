package EnsEMBL::Web::Component::Help::FeedbackPreview;

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

  my $form = EnsEMBL::Web::Form->new( 'contact', "/Help/MovieEmail", 'post' );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Subject',
    'value'   => 'Feedback for Ensembl tutorial movies',
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'subject',
    'value'   => 'Feedback for Ensembl tutorial movies',
  );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Movie title',
    'value'   => $hub->param('title'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'title',
    'value'   => $hub->param('title'),
  );

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
    'name'    => 'email',
    'value'   => $hub->param('address'),
  );

  my $problems = {
    'no_load'   => 'Movie did not appear',
    'playback'  => 'Playback was jerky',
    'no_sound'  => 'No sound',
    'bad_sound' => 'Poor quality sound',
    'other'     => 'Other (please describe below)',
  };

  my @problems = $hub->param('problem');
  my $problem_text;
  if (@problems) {
    $problem_text .= '<ul>';
    foreach my $p (@problems) {
      next unless $p && $problems->{$p};
      $problem_text .= '<li>'.$problems->{$p}.'</li>';
      $form->add_element(
        'type'  => 'Hidden',
        'name'  => 'problem',
        'value' => $p,
      );
    }
    $problem_text .= '</ul>';
  }
  
  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Problem(s)',
    'value'  => $problem_text,
  );

  $form->add_element(
    'type'    => 'NoEdit',
    'label'   => 'Additional comments',
    'value'   => $hub->param('text'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'message',
    'value'   => $hub->param('text'),
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
    'value'   => 'Send email',
  );

  return $form->render;
}

1;
