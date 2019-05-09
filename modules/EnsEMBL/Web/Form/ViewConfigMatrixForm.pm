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

package EnsEMBL::Web::Form::ViewConfigMatrixForm;

use strict;
use warnings;

use HTML::Entities qw(encode_entities);

use parent qw(EnsEMBL::Web::Form::ViewConfigForm);

sub render {
  ## @override
  ## Ignore wrapping form tag when returning HTML
  my $self = shift;

  return $self->SUPER::render(@_) =~ s/^[^>]+>|<[^<]+$//gr;
}

sub js_panel {
  ## Panel used by JS
  my $self = shift;
  return $self->get_js_panel();
}

sub build {
  ## Build the html form for both image config and view config
  my ($self, $object, $image_config) = @_;

  my $hub           = $self->view_config->hub;
  my $img_url       = $self->view_config->species_defs->img_url;
  my $tree          = $image_config->tree;
  my $menu          = $hub->param('menu');

  my $menu_node     = $tree->get_node($menu);
  my $matrix_data   = $menu_node->get_data('matrix');
  
  #use Data::Dumper;
  #$Data::Dumper::Sortkeys = 1;
  #$Data::Dumper::Maxdepth = 2;
  #warn Dumper($matrix_data);
  my $title = $matrix_data->{'section'};
  my $dimX  = $matrix_data->{'axes'}{'x'};
  my $dimY  = $matrix_data->{'axes'}{'y'};

  my $html = qq(
    <div class="header_tutorial_wrapper flex-row">
      <h1>$title</h1>
      <div class="large-breadcrumbs">
        <ul>
          <li class="active _track-select" id="track-select"><a href="#"><span class="circle crumb-number">1</span>Select tracks</a><span class="hidden content-id">track-content</span></li>
          <li class="inactive _configure" id="track-display"><a href="#"><span class="circle crumb-number">2</span>Configure track display</a><span class="hidden content-id">configuration-content</span></li>
        </ul>
      </div>
      <button class="fade-button view-track">View tracks</button>
    </div>
    <div class="flex-row">
      <div class="track-panel active noselect" id="track-content">
        <div class="tabs track-menu">
          <div class="track-tab active" id="dx-tab">
            <span class="tab-header"> $dimX </span>
            <span class="hidden content-id">dx-content</span>
            <div class="search-box">
              <input class="configuration_search_text" placeholder="Find..." id="dx_search" name="matrix_search">
              <span class="search-cross-icon">x</span>
              <img src="/i/16/search.png" class="search-icon" />
            </div>
          </div>
          <div class="track-tab" id="dy-tab">
            <span class="tab-header"> $dimY </span>
            <span class="hidden content-id">dy-content</span>
            <div class="search-box">
              <input class="configuration_search_text" placeholder="Find..." id="dy_search" name="matrix_search">
              <span class="search-cross-icon">x</span>
              <img src="/i/16/search.png"  class="search-icon"/>
            </div>
          </div>
        </div>

        <div id="dx-content" class="tab-content active" data-rhsection-id="dx">
          <span class="hidden rhsection-id">dx</span>
        </div>

        <div id="dy-content" class="tab-content" data-rhsection-id="dy">
          <span class="hidden rhsection-id">dy</span>
        </div>
      </div>
  );

  $html .= $self->configuration_content($dimX, $dimY); 

  $html .= qq(
        <div class="bottom-buttons">
          <div class="save-config-wrapper">
            <span class="fancy-checkbox inactive"></span>
            <text class="save-config">Save configuration</text>
          </div>
          <button class="showMatrix fade-button">Configure track display</button>
        </div>
      </div>
    </div>
  );

  my $js_panel = $self->get_js_panel();
  $self->append_child('div', { inner_HTML => $html, class => "js_panel $js_panel", id => $js_panel });
}

1;
