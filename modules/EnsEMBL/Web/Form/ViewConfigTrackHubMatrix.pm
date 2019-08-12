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
          <li class="inactive view-track"><a href="#"><span class="circle crumb-number">3</span>View tracks</a></li>
        </ul>
      </div>
      <div class="large-breadcrumbs multiDim">
        <ul>
          <li class="active _track-select" id="track-select"><a href="#"><span class="circle crumb-number">1</span>Select tracks</a><span class="hidden content-id">track-content</span></li>
          <li class="inactive _configure" id="track-filter"><a href="#"><span class="circle crumb-number">2</span>Filter tracks</a><span class="hidden content-id">filter-content</span></li>
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
          <div class="config-key"><span class="track-key on"></span>Tracks on(all)</div>
          <div class="config-key"><span class="track-key partial"></span>Tracks on & off</div>
          <div class="config-key"><span class="track-key off"></span>Tracks off(all)</div>
          <div class="config-key"><span class="track-key no-data"></span>No data</div>
        </div>
        <div class="horizontal-sub-header _dyMatrixHeader">$dimY</div>
        <button class="fade-button reset-button _filterMatrix">Reset</button>
        <div class="matrix-container-wrapper">
          <div class="hidebox"></div>
          <div class="filterMatrix-container"></div>
          <div class="track-popup _filterMatrix"><ul></ul></div>
        </div>
      </div>

      <div class="result-box" id="filter-box">
        <h4>Track filters</h4>
        <div class="filter-content">
        
        </div>
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
          <div class="config-key"><span class="track-key on"></span>Data track on</div>
          <div class="config-key"><span class="track-key off"></span>Data track off</div>
          <div class="config-key"><span class="track-key no-data"></span>No data</div>
        </div>
        <div class="horizontal-sub-header _dyMatrixHeader">$dimY</div>
        <button class="fade-button reset-button _matrix">Reset all</button>

        <div class="matrix-container-wrapper">
          <div class="hidebox"></div>
          <div class="matrix-container"></div>
          <div class="track-popup column-cell">
            <ul class="_cell">
              <li>
                <label class="switch">
                  <input type="checkbox" name="cell-switch">
                  <span class="slider round"></span>
                </label>
                <span class="switch-label">Cell on/off</span>
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
              <li>
                <label class="wide-label"> All cells </label>
                <div>
                  <input type="radio" id="on_all_cells" name="all_cells" value="on"> <label for="all_cells"> On </label>
                  <input type="radio" id="off_all_cells" name="all_cells" value="off"> <label for="off"> Off </label>
                  <div class="reset_track_state">Reset</div>
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

          <h5 class="result-header">$dimX <span class="error _dx">Please select $dimX</span></h5>
          <div class="result-content" id="dx">
            <div class="_show show-hide hidden"><img src="/i/closed2.gif" class="nosprite" /></div><div class="_hide show-hide hidden"><img src="/i/open2.gif" class="nosprite" /></div>
            <div class="sub-result-link">$dimX</div>
            <div class="count-container"><span class="current-count">0</span> / <span class="total"></span> available</div>
            <ul class="result-list hidden">
              <span class="hidden lhsection-id">dx-content</span>
            </ul>
          </div>

          <h5 class="result-header">$dimY<span class="error _dy">Please select $dimY</span></h5>
          <div class="result-content" id="dy">
            <div class="sub-result-link">$dimY</div>
            <div class="count-container"><span class="current-count">0</span> / <span class="total"></span> available</div>
<div class="_show show-hide hidden"><img src="/i/closed2.gif" class="nosprite" /></div><div class="_hide show-hide hidden"><img src="/i/open2.gif" class="nosprite" /></div>
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
