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

package EnsEMBL::Web::ViewConfig::Variation::Mappings;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig);

sub init_cacheable {
  ## Abstract method implementation
  my $self = shift;

  $self->set_default_options({'motif_scores' => 'no'});
  $self->title('Genes and regulation');
}

sub field_order {
  ## Abstract method implementation
  return $_[0]->hub->species =~ /homo_sapiens|mus_musculus/i ? qw(motif_scores) : (); # TODO - don't hardcode species, add a variable in ini files
}

sub form_fields {
  ## Abstract method implementation
  return {
    'motif_scores' => {
      'type'  => 'CheckBox',
      'label' => 'Show regulatory motif binding scores',
      'name'  => 'motif_scores',
      'value' => 'yes',
    }
  };
}

1;
