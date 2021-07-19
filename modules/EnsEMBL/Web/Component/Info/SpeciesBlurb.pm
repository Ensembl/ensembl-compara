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
  ## Simple template that we can populate differently in plugins
  my $self              = shift;

  my $html = sprintf('
<div class="column-wrapper">  
  <div class="column-one">
    %s
  </div>
</div>', $self->page_header);

  ## Don't mark up archives, etc - it will only confuse search engine users
  ## if there are e.g. multiple human gene sets in the results!
  $html .= $self->include_bioschema_datasets if $self->hub->species_defs->BIOSCHEMAS_DATACATALOG;

  $html .= sprintf('%s
<div class="column-wrapper">  
  <div class="column-two">
    %s
  </div>
  <div class="column-two">
    %s
  </div>
</div>', 
    $self->side_nav, $self->column_left, $self->column_right);

  return $html;
}

sub page_header {
  my $self      = shift;
  my $hub               = $self->hub;
  my $path              = $hub->species_path;
  my $image             = $hub->species_defs->SPECIES_IMAGE;
  my $display_name       = $hub->species_defs->SPECIES_DISPLAY_NAME;

  my $html = qq(
    <div class="column-padding no-left-margin species-box">
      <a href="$path"><img class="badge-48" src="/i/species/$image.png" class="species-img float-left" alt="" /></a>
      <h1 class="no-bottom-margin">$display_name assembly and gene annotation</h1>
    </div>
  );

  return $html;
}

sub column_left {
  my $self      = shift;
  my $species   = $self->hub->species;
  
  my $html = '<div class="column-padding no-left-margin">';

  ### SPECIES DESCRIPTION
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_description.html");
### ASSEMBLY
  $html .= '<h2 id="assembly">Assembly</h2>';
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_assembly.html");

  if (my $assembly_dropdown = $self->assembly_dropdown) {
    $html .= "<h2>Other assemblies</h2>$assembly_dropdown";
  }
  
  $html .= '<h2 id="genebuild">Gene annotation</h2>';
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_annotation.html");

  $html .= $self->include_more_annotations();

  ## Link to Wikipedia
  $html .= $self->_wikipedia_link; 

  $html .= '</div>';

  return $html;
}

sub column_right { 
  my $self              = shift;

  my $html .= '<div class="column-padding annotation-stats">';
    
  ## ASSEMBLY STATS 
  my $file = '/ssi/species/stats_' . $self->hub->species . '.html';
  $html .= '<h2>Statistics</h2>';
  $html .= $self->species_stats;

  $html .= '</div>';

  return $html;  
}

# MOBILE - This is implemented in the mobile plugins to create the side menu for the species annotation page
# Return empty string for www
sub side_nav {
  return "";
}

sub _wikipedia_link {
## Factored out so that other sites can override it easily
  my $self = shift;
  my $species = $self->hub->species_defs->SPECIES_SCIENTIFIC_NAME;
  $species =~ s/ /_/g;;
  my $html = qq(<h2>More information</h2>
<p>General information about this species can be found in 
<a href="http://en.wikipedia.org/wiki/$species" rel="external">Wikipedia</a>.
</p>); 

  return $html;
}

1;
