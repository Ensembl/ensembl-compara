=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::UserData::MoreInput;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $species = $hub->param('species') || $hub->data_species;
  my $form    = $self->modal_form('more_input', $hub->species_path($species) . '/UserData/UploadFile/set_format', { wizard => 1 });

  $form->add_element(type => 'Hidden', name => 'code', value => $hub->param('code'));
  $form->add_element(type => 'Information',            value => 'Your file format could not be identified - please select an option:');
  $self->add_file_format_dropdown($form, 'upload');

  return $form->render;
}

1;
