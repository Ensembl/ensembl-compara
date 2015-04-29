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

package EnsEMBL::Web::ViewConfig::Regulation::FeaturesByCellLine;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Regulation::Page);

sub init {
  my $self = shift;
  $self->title = 'Details by cell type';
  $self->add_image_config('regulation_view');
  $self->set_defaults({ opt_highlight => 'yes', context => 200 });
}

sub form {
  my $self = shift;
  
  $self->add_fieldset('Display options');
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Context',
    values => [
      { value => 20,   caption => '20bp'   },
      { value => 50,   caption => '50bp'   },
      { value => 100,  caption => '100bp'  },
      { value => 200,  caption => '200bp'  },
      { value => 500,  caption => '500bp'  },
      { value => 1000, caption => '1000bp' },
      { value => 2000, caption => '2000bp' },
      { value => 5000, caption => '5000bp' }
    ]
  });
  
  $self->add_form_element({ type => 'YesNo', name => 'opt_highlight', select => 'select', label => 'Highlight core region' });
}

sub extra_tabs { return $_[0]->reg_extra_tabs('regulation_view'); }

1;
