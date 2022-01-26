=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
