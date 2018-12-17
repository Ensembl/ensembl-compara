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
  return 'ConfigMatrixForm';
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
  
  my $html = qq(
    <div class="header_tutorial_wrapper flex-row">
      <h1>Regulation data</h1>
      <div class="large-breadcrumbs">
        <ul>
          <li class="active _track-select"><a href="#"><span class="circle crumb-number">1</span>Select tracks</a><span class="hidden content-id">track-content</span></li>
          <li class="inactive _configure"><a href="#"><span class="circle crumb-number">2</span>Configure display</a><span class="hidden content-id">configuration-content</span></li>
        </ul>
      </div>
      <button class="fade-button view-track">View tracks</button>
    </div>
    <div class="flex-row">
      <div class="track-panel active" id="track-content">
        <div class="tabs track-menu">
          <div class="track-tab active" id="cell-tab">
            <span> Epigenome </span>
            <span class="hidden content-id">cell-content</span>
            <div class="search-box">
              <input class="configuration_search_text" placeholder="Search" name="cell_search">
              <img src="/i/16/search.png" class="search-icon" />
            </div>
          </div>
          <div class="track-tab" id="experiment-tab">
            <span> Experimental data </span>
            <span class="hidden content-id">experiment-content</span>
            <div class="search-box">
              <input class="configuration_search_text" placeholder="Search" name="experiment_search">
              <img src="/i/16/search.png"  class="search-icon"/>
            </div>
          </div>
        </div>

        <div id="cell-content" class="tab-content active" data-rhsection-id="cell">
          <span class="hidden rhsection-id">cell</span>
        </div>

        <div id="experiment-content" class="tab-content" data-rhsection-id="experiment">
          <span class="hidden rhsection-id">experiment</span>
        </div>
      </div>
        
      <div class="track-panel track-configuration" id="configuration-content">
        <div class="vertical-sub-header">Epigenome</div>
        <div class="configuration-legend">
          <div class="config-key"><span class="track-key on"></span>Data track on</div>
          <div class="config-key"><span class="track-key off"></span>Data track off</div>
          <div class="config-key"><span class="track-key no-data"></span>No data</div>
          <div class="config-key"><span class="track-key peak"><img src="/i/render/peak_blue50.svg" /></span>Peaks</div>
          <div class="config-key"><span class="track-key signal"><img src="/i/render/signal_blue50.svg" /></span>Signal</div>
        </div>
        <div class="horizontal-sub-header">Experimental data</div>
        <button class="fade-button reset">Reset</button>
        <div class="matrix-container">  
        </div>        
      </div>

      <div class="result-box">
        <h4>Selected tracks</h4>

        <div class="filter-content">
          <h5 class="result-header">Epigenome <span class="error _cell">Please select Epigenome</span></h5>
          <div class="result-content" id="cell">
            <div class="sub-result-link">Epigenome</div>
            <div class="count-container"><span class="current-count">0</span> / <span class="total"></span> available</div>
            <div class="_show show-hide hidden">Show selected</div><div class="_hide show-hide hidden">Hide selected</div>
            <ul class="result-list hidden">
              <span class="hidden lhsection-id">cell-content</span>
            </ul>
          </div>

          <h5 class="result-header">Experimental data <span class="error _experiment">Please select Experimental data</span></h5>
          <div id="experiment">
            <div class="result-content" id="Histone">
              <span class="_parent-tab-id hidden">experiment-tab</span>
              <div class="sub-result-link">Histone</div>
              <div class="count-container"><span class="current-count">0</span> / <span class="total"></span> available</div>
              <div class="_show show-hide hidden">Show selected</div><div class="_hide show-hide hidden">Hide selected</div>
              <ul class="result-list hidden">
                <span class="hidden lhsection-id">Histone-content</span>
              </ul>
            </div>
            <div class="result-content" id="Open_Chromatin">
							<span class="_parent-tab-id hidden">experiment-tab</span>
              <div class="sub-result-link">Open chromatin</div>
              <div class="count-container"><span class="current-count">0</span> / <span class="total"></span> available</div>
              <div class="_show show-hide hidden">Show selected</div><div class="_hide show-hide hidden">Hide selected</div>
              <ul class="result-list hidden">
                <span class="hidden lhsection-id">Open_Chromatin-content</span>
              </ul>
            </div>
            <div class="result-content" id="Polymerase">
							<span class="_parent-tab-id hidden">experiment-tab</span>
              <div class="sub-result-link">Polymerase</div>
              <div class="count-container"><span class="current-count">0</span> / <span class="total"></span> available</div>
              <div class="_show show-hide hidden">Show selected</div><div class="_hide show-hide hidden">Hide selected</div>
              <ul class="result-list hidden">
                <span class="hidden lhsection-id">Polymerase-content</span>
              </ul>
            </div>          
            <div class="result-content" id="TFBS">
              <span class="_parent-tab-id hidden">experiment-tab</span>
							<div class="sub-result-link">TFBS</div>
              <div class="count-container"><span class="current-count">0</span> / <span class="total"></span> available</div>
              <div class="_show show-hide hidden">Show selected</div><div class="_hide show-hide hidden">Hide selected</div>
              <ul class="result-list hidden">
                <span class="hidden lhsection-id">TFBS-content</span>
              </ul>
            </div>
          </div>

          <h5 class="result-header">Source <span class="error _source hidden">Please select Source</span></h5>
          <div class="result-content" id="source">
            <ul class="result-list no-left-margin">
              <span class="hidden lhsection-id">source-content</span>
              <li class="noremove">
                <span class="fancy-checkbox selected"></span><text>Blueprint</text>
              </li>
              <li class="noremove">
                <span class="fancy-checkbox selected"></span><text>Another source</text>
              </li>
            </ul>
          </div>
        </div>

        <div class="bottom-buttons">
          <div class="save-config-wrapper">
            <span class="fancy-checkbox inactive"></span>
            <text class="save-config">Save configuration</text>
          </div>
          <button class="filter fade-button">Configure track display</button>
        </div>
      </div>
    </div>
  );

  $self->append_child('div', { inner_HTML => $html, class => 'js_panel config_matrix_form', id => "matrix_form" });
}

1;
