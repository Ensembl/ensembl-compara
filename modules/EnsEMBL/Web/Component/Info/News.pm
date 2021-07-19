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

package EnsEMBL::Web::Component::Info::News;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self    = shift;
  my $builder = $self->builder;

  ## Fetch some news items
  $builder->create_data_object_of_type('News');

  my $stories = $builder->object('News')->get_stories;

  ## Output stories
  my $html;

  foreach my $story (@$stories) {
    $html .= '<h2>' . $story->title   . '</h2>';
    $html .= '<p>'  . $story->content . '</p>';
  }

  return $html;
}

1;
