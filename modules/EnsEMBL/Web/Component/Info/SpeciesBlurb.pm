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

package EnsEMBL::Web::Component::Info::SpeciesBlurb;

use strict;

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Component::Info);


sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self              = shift;
  my $hub               = $self->hub;
  my $species_defs      = $hub->species_defs;
  my $species           = $hub->species;
  my $path              = $hub->species_path;
  my $common_name       = $species_defs->SPECIES_COMMON_NAME;
  my $accession         = $species_defs->ASSEMBLY_ACCESSION;
  my $source            = $species_defs->ASSEMBLY_ACCESSION_SOURCE || 'NCBI';
  my $source_type       = $species_defs->ASSEMBLY_ACCESSION_TYPE;

  my $html = qq(
<div class="column-wrapper">  
  <div class="column-one">
    <div class="column-padding no-left-margin">
      <a href="$path"><img src="/i/species/48/$species.png" class="species-img float-left" alt="" /></a>
      <h1 class="no-bottom-margin">$common_name assembly and gene annotation</h1>
    </div>
  </div>
</div>
          );

  $html .= '
<div class="column-wrapper">  
  <div class="column-two">
    <div class="column-padding no-left-margin">';
### ASSEMBLY
  $html .= '<h2 id="assembly">Assembly</h2>';
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_assembly.html");

  $html .= sprintf '<p>The genome assembly represented here corresponds to %s %s</p>', $source_type, $hub->get_ExtURL_link($accession, "ASSEMBLY_ACCESSION_SOURCE_$source", $accession) if $accession; ## Add in GCA link

  if (my $assembly_dropdown = $self->assembly_dropdown) {
    $html .= "<h2>Other assemblies</h2>$assembly_dropdown";
  }
  
  $html .= '<h2 id="genebuild">Gene annotation</h2>';
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_annotation.html");

  ## Link to Wikipedia
  $html .= $self->_wikipedia_link; 
  
  $html .= '
    </div>
  </div>
  <div class="column-two">
    <div class="column-padding" class="annotation-stats">';
    
  ## ASSEMBLY STATS 
  my $file = '/ssi/species/stats_' . $self->hub->species . '.html';
  $html .= '<h2>Statistics</h2>';
  $html .= $self->species_stats;

  $html .= '
    </div>
  </div>
</div>';

  return $html;  
}

sub _wikipedia_link {
## Factored out so that other sites can override it easily
  my $self = shift;
  my $species = $self->hub->species;
  my $html = qq(<h2>More information</h2>
<p>General information about this species can be found in 
<a href="http://en.wikipedia.org/wiki/$species" rel="external">Wikipedia</a>.
</p>); 

  return $html;
}

1;
