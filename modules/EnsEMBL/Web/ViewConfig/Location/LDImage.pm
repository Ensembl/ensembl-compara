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

package EnsEMBL::Web::ViewConfig::Location::LDImage;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use parent qw(EnsEMBL::Web::ViewConfig);

sub init_cacheable {
  ## Abstract method implementation
  my $self     = shift;
  my %options  = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my $defaults = {};

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    $defaults->{lc $_} = $hash{$_}[0] for keys %hash;
  }

  $self->set_default_options($defaults);
  $self->image_config_type('ldview');
  $self->title('Linkage Disequilibrium');
}

sub form_fields { } # No default fields
sub field_order { } # No default fields

sub extra_tabs {
  ## @override
  my $self = shift;
  my $hub  = $self->hub;

  # referer_action is added to ensure the correct action can be used by PopulationSelector when the OK icon is clicked
  return [
    'Select populations',
    $hub->url('MultiSelector', {
      action   => 'SelectPopulation',
      referer_action => $hub->action,
      %{$hub->multi_params}
    })
  ];
}

1;
