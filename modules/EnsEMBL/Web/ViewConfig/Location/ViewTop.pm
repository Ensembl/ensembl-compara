=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Location::ViewTop;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig);

sub init_cacheable {
  ## Abstract method implementation
  my $self = shift;

  $self->set_default_options({
    'show_panel'  => 'yes',
    'flanking'    => 0,
  });

  $self->image_config_type('contigviewtop');
  $self->title('Overview Image');
}

sub field_order {
  ## Abstract method implementation
  return qw(flanking show_panel);
}

sub form_fields {
  ## Abstract method implementation
  my $self = shift;

  return {
    'flanking'    => {
      'type'        => 'NonNegInt',
      'required'    => 'yes',
      'label'       => 'Flanking region',
      'name'        => 'flanking',
      'notes'       => sprintf('Ignored if 0 or region is larger than %sMb', $self->hub->species_defs->ENSEMBL_GENOME_SIZE || 1),
    },
    'show_panel'  => {
      'type'        => 'YesNo',
      'name'        => 'show_panel',
      'label'       => 'Show panel'
    }
  };
}

1;
