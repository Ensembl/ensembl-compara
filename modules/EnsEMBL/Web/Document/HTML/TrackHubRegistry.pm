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
    my $url = $hub->url({'species' => $species, 'type' => 'UserData', 'action' => 'TrackHubSearch'});
    my $display_name = $species_defs->get_config($species, 'SPECIES_DISPLAY_NAME');

    $html = qq(<p>Alternatively to search for track hubs from within Ensembl:</p>
<ol>
  <li>Click on 'Track Hub Registry Search' in the lefthand menu of the popup window.</li>
  <li>Submit your search and find the hub you are interested in</li>
  <li>Click on 'Add this trackhub' to load the hub</li>
  <li>Once you see the message 'Your hub attached successfully', either 
    <ul>
      <li>close the window to see the hub with its default configuration</li>
      <li>or click on the 'Configure region image' tab in the popup window to change the configuration</li>
    </ul>
  </li>
</ol>
<p>&rarr; See the <a href="$url" class="modal_link">Track Hub Registry Search</a> for $display_name.</p>
);
  }

  return $html;  
}

1;
