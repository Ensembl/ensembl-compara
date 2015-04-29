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

package EnsEMBL::Web::ViewConfig::Karyotype;

### Base for all Karyotype based view configs

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    chr_length => 300,
    h_padding  => 4,
    h_spacing  => 6,
    v_spacing  => 10,
    rows       => scalar @{$self->species_defs->ENSEMBL_CHROMOSOMES} >= 26 ? 2 : 1,
  });
}

sub form {
  my $self = shift;

  $self->add_form_element({
    type    => 'DropDown',
    name    => 'rows',
    label   => 'Number of rows of chromosomes',
    select  => 'select',
    values  => [
      { caption => 1, value => 1 },
      { caption => 2, value => 2 },
      { caption => 3, value => 3 },
      { caption => 4, value => 4 },
    ],
  });

  $self->add_form_element({
    type     => 'PosInt',
    name     => 'chr_length',
    label    => 'Height of the longest chromosome (pixels)',
    required => 'yes',
  });
}

1;
