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

package EnsEMBL::Web::ViewConfig::Location::Compara_AlignSliceBottom;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::Location::Compara_Alignments);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable;

  $self->image_config_type('alignsliceviewbottom');
  $self->title('Alignments Image');

  $self->set_default_options({
    'opt_conservation_scores'   => 'off',
    'opt_constrained_elements'  => 'off',
  });
}

sub field_order {
  ## @override
  return qw(image_width opt_conservation_scores opt_constrained_elements);
}

sub form_fields {
  ## @override
  my $fields = shift->SUPER::form_fields(@_);

  $fields->{'opt_conservation_scores'} = {
    'fieldset'  => 'Comparative features',
    'type'      => 'CheckBox',
    'label'     => 'Conservation scores for the selected alignment',
    'name'      => 'opt_conservation_scores',
    'value'     => 'tiling',
  };

  $fields->{'opt_constrained_elements'} = {
    'fieldset'  => 'Comparative features',
    'type'      => 'CheckBox',
    'label'     => 'Constrained elements for the selected alignment',
    'name'      => 'opt_constrained_elements',
    'value'     => 'compact',
  };

  return $fields;
}

1;
