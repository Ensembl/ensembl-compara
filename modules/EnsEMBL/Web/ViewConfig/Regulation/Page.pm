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

package EnsEMBL::Web::ViewConfig::Regulation::Page;

# Really this should be a superclass for regulation VeiwConfigs, but the
# code picks that package name up even for components without viewconfigs in
# their own right (eg Buttons component).

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub reg_extra_tabs {
  my ($self, $image_config) = @_;
  my $hub = $self->hub;
  
  return ([
    'Select cell types',
    $hub->url('Component', {
      action       => 'Web',
      function     => 'CellTypeSelector/ajax',
      image_config => $image_config,
      time         => time,
      %{$hub->multi_params}
    })],[
    'Select evidence',
    $hub->url('Component', {
      action   => 'Web',
      function => 'EvidenceSelector/ajax',
      time     => time,
      %{$hub->multi_params}
    })],
  );
}

1;
