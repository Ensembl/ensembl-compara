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

package EnsEMBL::Web::ViewConfig::Karyotype;

### Base for all Karyotype based view configs

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig);

sub init_cacheable {
  ## Abstract method implementation
  my $self = shift;

  $self->set_default_options({
    'chr_length'  => 300,
    'h_padding'   => 4,
    'h_spacing'   => 6,
    'v_spacing'   => 10,
    'rows'        => scalar @{$self->species_defs->ENSEMBL_CHROMOSOMES} >= 26 ? 2 : 1,
  });
}

sub field_order {
  ## Abstract method implementation
  return qw(rows chr_length);
}

sub form_fields {
  ## Abstract method implementation
  return {
    'rows' => {
      'type'    => 'dropdown',
      'name'    => 'rows',
      'label'   => 'Number of rows of chromosomes',
      'values'  => [ qw(1 2 3 4) ],
    },
    'chr_length' => {
      'type'      => 'posint',
      'name'      => 'chr_length',
      'label'     => 'Height of the longest chromosome (pixels)',
      'required'  => 1,
    }
  };
}

1;
