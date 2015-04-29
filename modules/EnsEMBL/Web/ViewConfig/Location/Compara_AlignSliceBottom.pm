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

package EnsEMBL::Web::ViewConfig::Location::Compara_AlignSliceBottom;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Location::Compara_Alignments);

sub init {
  my $self = shift;
  
  $self->SUPER::init;
  
  $self->add_image_config('alignsliceviewbottom', 'nodas');
  
  $self->title            = 'Alignments Image';
  $self->{'species_only'} = 1;
  
  $self->set_defaults({
    opt_conservation_scores  => 'off',
    opt_constrained_elements => 'off',
  });
}

sub form {
  my $self = shift;
  
  $self->add_fieldset('Comparative features');
  
  $self->add_form_element({
    type  => 'CheckBox', 
    label => 'Conservation scores for the selected alignment',
    name  => 'opt_conservation_scores',
    value => 'tiling',
  });
  
  $self->add_form_element({
    type  => 'CheckBox', 
    label => 'Constrained elements for the selected alignment',
    name  => 'opt_constrained_elements',
    value => 'compact',
  });
  
  $self->SUPER::form;
}

1;
