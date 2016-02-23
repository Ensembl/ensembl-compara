=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::TrackHubRegistry;

### Renders the content of the  "Find a species page" linked to from the SpeciesList module

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my ($self, $request) = @_;

  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my @valid_species = $species_defs->valid_species;
  my $species       = grep $hub->species, @valid_species;
  $species          ||= $species_defs->ENSEMBL_PRIMARY_SPECIES;

  my $html;

  if ($species) {
    my %sample_data = %{$species_defs->get_config($species, 'SAMPLE_DATA') || {}};
    my $r   = $hub->param('r') || $sample_data{'LOCATION_PARAM'};
    my $url = $hub->url({'species' => $species, 'type' => 'Location', 'action' => 'View', 'r' => $r});
    my $common_name = $species_defs->get_config($species, 'SPECIES_COMMON_NAME');

    $html = qq(<p>To search for Track Hubs from within Ensembl, go to
Region in Detail, click on 'Add your data' and select
'<b>Track Hub Registry Search</b>' from the lefthand menu.
</p>
<p>&rarr; See the <a href="$url" class="modal_link">Track Hub Registry Search</a> for $common_name.</p>
);
  }

  return $html;  
}

1;
