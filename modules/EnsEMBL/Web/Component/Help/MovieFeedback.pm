=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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
