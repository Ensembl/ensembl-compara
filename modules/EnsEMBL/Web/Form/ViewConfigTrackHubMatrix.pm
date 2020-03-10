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

package EnsEMBL::Web::Form::ViewConfigTrackHubMatrix;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Form::ViewConfigMatrixForm);

sub get_js_panel {
  return 'ConfigTrackHubMatrixForm';
}

sub breadcrumb_html {
  my ($self)  = @_;

  my $html = qq(
      <div class="large-breadcrumbs twoDim">
        <ul>
          <li class="active _track-select" id="track-select"><a href="#"><span class="circle crumb-number">1</span>Select tracks</a><span class="hidden content-id">track-content</span></li>
          <li class="inactive _configure" id="track-display"><a href="#"><span class="circle crumb-number">2</span>Configure track display</a><span class="hidden content-id">configuration-content</span></li>
        </ul>
      </div>
      <div class="large-breadcrumbs multiDim">
        <ul>
          <li class="active _track-select" id="track-select"><a href="#"><span class="circle crumb-number">1</span>Select tracks</a><span class="hidden content-id">track-content</span></li>
          <li class="inactive _configure" id="track-filter"><a href="#"><span class="circle crumb-number">2</span>Refine selection</a><span class="hidden content-id">filter-content</span></li>
          <li class="inactive _configure" id="track-display"><a href="#"><span class="circle crumb-number">3</span>Configure track display</a><span class="hidden content-id">configuration-content</span></li>
        </ul>
      </div>      
      <button class="inactive view-track-button fade-button">View tracks</button>
  );

  return $html;
}

sub configuration_content {
  my ($self, $dimX, $dimY) = @_;

#filter track panel
  my $html = qq(
      <div class="track-panel filter-track" id="filter-content">
        <div class="vertical-sub-header">$dimX</div>
        <div class="configuration-legend">
          <div class="config-key"><span class="track-key on"></span>All tracks on</div>
          <div class="config-key"><span class="track-key partial"></span>Some tracks on</div>
          <div class="config-key"><span class="track-key partzero"></span>All tracks off</div>
          <div class="config-key"><span class="track-key no-data"></span>No data</div>
        </div>
        <button class="fade-button reset-button _filterMatrix">Reset</button>
        <div class="matrix-container-wrapper">
          <div class="horizontal-sub-header _dyMatrixHeader">$dimY</div>
          <div class="hidebox"></div>
          <div class="filterMatrix-container"></div>
          <div class="track-popup _filterMatrix"><div class="title">Available tracks</div><ul></ul></div>
        </div>
      </div>

      <div class="result-box" id="filter-box">
        <h4>More filtering options</h4>
        <div class="filter-content">
        
        </div>
        <div class="filter-rhs-popup"></div>
        <div class="bottom-buttons">
          <button class="filterConfigButton fade-button active">Configure track display</button>
        </div>

      </div>
  );

  # track configuration panel (final matrix)
  $html .= qq(
      <div class="track-panel track-configuration" id="configuration-content">
        <div class="vertical-sub-header">$dimX</div>
        <div class="configuration-legend">
          <div class="config-key"><span class="track-key on"></span>Track(s) on</div>
          <div class="config-key"><span class="track-key off"></span>Track(s) off</div>
          <div class="config-key"><span class="track-key no-data"></span>No data</div>
        </div>
        <button class="fade-button reset-button _matrix">Reset</button>

        <div class="matrix-container-wrapper">
          <div class="horizontal-sub-header _dyMatrixHeader">$dimY</div>
          <div class="hidebox"></div>
          <div class="matrix-container"></div>
          <div class="track-popup column-cell">
            <ul class="_cell">
              <li>
                <div>
                  <label class="switch">
                    <input type="checkbox" name="cell-switch">
                    <span class="slider round"></span>
                  </label>
                  <span class="switch-label">Cell on/off</span>
                </div>
                <div class="all-cells-state">
                  <label for="all-cells-stateBox"> All cells </label>
                  <input id="all-cells-stateBox" type="checkbox" name="all-cells" checked=false> 
                </div>              
              </li>
              <li class="renderer-selection">
                <label class="wide-label"> Cell style </label>
                <div class="cell-style">
            
                  <div id="dd" class="renderers">
                    <span>Select Renderer</span>
                    <ul class="dropdown"></ul>
                  </div>

                  <div>
                    <input id="apply_to_all" type="checkbox" checked=false>
                    <label for="apply_to_all">Apply to all cells of this type</label>
                  </div>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </div>

      <div class="result-box" id="config-result-box">
        <h4>Selected tracks</h4>
        <div class="config-result-box-content"></div>
      </div>

      <div class="result-box" id="selected-box">
        <h4>Selected tracks</h4>
        <div class="reset_track">Reset all</div>

        <div class="filter-content">

          <h5 class="result-header" data-header="$dimX">$dimX</h5>
          <div class="result-content" id="dx">
            <div class="_show show-hide hidden"><img src="/i/closed2.gif" class="nosprite" /></div><div class="_hide show-hide hidden"><img src="/i/open2.gif" class="nosprite" /></div>
            <div class="sub-result-link">$dimX</div>
            <div class="count-container"><span class="current-count">0</span> / <span class="total"></span> available</div>
            <ul class="result-list hidden">
              <span class="hidden lhsection-id">dx-content</span>
            </ul>
          </div>

          <h5 class="result-header" data-header="$dimY">$dimY</h5>
          <div class="result-content" id="dy">
            <div class="sub-result-link">$dimY</div>
            <div class="_show show-hide hidden"><img src="/i/closed2.gif" class="nosprite" /></div><div class="_hide show-hide hidden"><img src="/i/open2.gif" class="nosprite" /></div>
            <div class="count-container"><span class="current-count">0</span> / <span class="total"></span> available</div>
            <ul class="result-list hidden">
              <span class="hidden lhsection-id">dy-content</span>
            </ul>
          </div>

        </div>
      <div>
  );

  return $html;
}

1;
