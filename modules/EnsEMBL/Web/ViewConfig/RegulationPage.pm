=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::RegulationPage;

### Parent class for regulation VeiwConfigs

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig);

sub form_fields {
  ## Abstract method implementation
  my $self = shift;

  return {
    'context' => {
      'fieldset'  => 'Display options',
      'type'      => 'DropDown',
      'name'      => 'context',
      'label'     => 'Context',
      'values'    => [
        { 'value' => 20,   'caption' => '20bp'   },
        { 'value' => 50,   'caption' => '50bp'   },
        { 'value' => 100,  'caption' => '100bp'  },
        { 'value' => 200,  'caption' => '200bp'  },
        { 'value' => 500,  'caption' => '500bp'  },
        { 'value' => 1000, 'caption' => '1000bp' },
        { 'value' => 2000, 'caption' => '2000bp' },
        { 'value' => 5000, 'caption' => '5000bp' }
      ]
    },
    'opt_focus' => {
      'type'  => 'YesNo',
      'name'  => 'opt_focus',
      'label' => 'Show Core Evidence track'
    },
    'opt_highlight' => {
      'type'  => 'YesNo',
      'name'  => 'opt_highlight',
      'label' => 'Highlight core region'
    }
  };
}

1;
