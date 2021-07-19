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

package EnsEMBL::Web::ViewConfig::Regulation::FeatureDetails;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::RegulationPage);

sub init_cacheable {
  ## Abstract method implementation
  my $self     = shift;
  my $analyses = {};
  if ( $self->species_defs->databases->{'DATABASE_FUNCGEN'} ) {
    $analyses = $self->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'feature_type'}{'analyses'} || {};
  }

  $self->set_default_options({
    'context'   => 200,
    'opt_focus' => 'yes',
    map {( "opt_ft_$_" => 'on' )} keys %$analyses
  });

  $self->image_config_type('reg_summary_page');
  $self->title('Summary');
}

sub field_order {
  ## Abstract method implementation
  return qw(context opt_focus);
}

sub extra_tabs {
  ## @override
}

1;
