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

package EnsEMBL::Web::ViewConfig::Transcript::PopulationTable;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Transcript::PopulationImage);

sub form {
  my $self = shift;
  $self->SUPER::form;

  # Add layout
  $self->add_fieldset('Grouping');

  $self->add_form_element({
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Group data by',
    name   => 'data_grouping',
    values => [
      { value => 'normal',   caption => 'By individual/population' },
      { value => 'by_variant',  caption => 'By variation ID and position' },
    ]
  });
}

1;
