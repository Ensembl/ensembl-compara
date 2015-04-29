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

package EnsEMBL::Web::ViewConfig::Location::ViewTop;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    show_panel => 'yes',
    flanking   => 0,
  });
  
  $self->add_image_config('contigviewtop', 'nodas');
  $self->title = 'Overview Image';
}

sub form {
  my $self = shift;
  
  $self->add_form_element({
    type     => 'NonNegInt', 
    required => 'yes',
    label    => 'Flanking region',
    name     => 'flanking',
    notes    => sprintf('Ignored if 0 or region is larger than %sMb', $self->hub->species_defs->ENSEMBL_GENOME_SIZE || 1),
   });
   
  $self->add_form_element({ type => 'YesNo', name => 'show_panel', select => 'select', label => 'Show panel' });
}

1;
