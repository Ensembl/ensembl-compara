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

package EnsEMBL::Web::Form::Element::SpeciesDropdown;

use strict;
use warnings;

use EnsEMBL::Web::SpeciesDefs;

use base qw(EnsEMBL::Web::Form::Element::Filterable);

sub configure {
  ## @overrrides
  my ($self, $params) = @_;

  my $sd = EnsEMBL::Web::SpeciesDefs->new;

  $self->SUPER::configure($params);

  $self->remove_attribute('class', '_fd');
  $self->set_attribute('class', '_sdd');

  $self->first_child->set_attributes({
    'class' => 'species-tag',
    'style' => {
      'background-image' => sprintf('url(%sspecies/%s.png)', $sd->img_url, $sd->ENSEMBL_PRIMARY_SPECIES),
      'background-size' => '16px'
    }
  });
}

1;
