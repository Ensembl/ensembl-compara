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

package EnsEMBL::Web::ViewConfig::Location::MultiTop;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig);

sub init_cacheable {
  ## Abstract method implementation
  my $self = shift;

  $self->set_default_options({
    'show_top_panel'      => 'yes',
    'opt_join_genes_top'  => 'off',
  });

  $self->image_config_type('MultiTop');
  $self->title('Comparison Overview');
}

sub field_order {
  ## Abstract method implementation
  my $self = shift;

  return qw(opt_join_genes_top);
}

sub form_fields {
  ## Abstract method implementation
  return {
    'opt_join_genes_top' => {
      'fieldset'  => 'Comparative features',
      'type'      => 'CheckBox',
      'label'     => 'Join genes',
      'name'      => 'opt_join_genes_top',
      'value'     => 'on',
    },
    'show_top_panel' => {
      'fieldset'  => 'Display options',
      'type'      => 'YesNo',
      'name'      => 'show_top_panel',
      'label'     => 'Show panel',
    }
  };
}

1;
