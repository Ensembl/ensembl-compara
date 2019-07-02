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
          <li class="inactive _configure" id="track-display"><a href="#"><span class="circle crumb-number">2</span>Filter tracks</a><span class="hidden content-id">filter-content</span></li>
          <li class="inactive _configure" id="track-display"><a href="#"><span class="circle crumb-number">3</span>Configure track display</a><span class="hidden content-id">configuration-content</span></li>
          <button class="inactive view-track fade-button">View tracks</button>
        </ul>
      </div>      
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
          <div class="config-key"><span class="track-key on"></span>Data track on</div>
          <div class="config-key"><span class="track-key off"></span>Data track off</div>
          <div class="config-key"><span class="track-key no-data"></span>No data</div>
        </div>
        <div class="horizontal-sub-header _dyMatrixHeader">$dimY</div>
        <div class="track-popup column-cell">
          <ul>
            <li>
              <label class="switch"><input type="checkbox" name="column-switch"><span class="slider round"></span><span class="switch-label">Column</span></label>
            </li>
          </ul>
        </div>
        <div class="hidebox"></div>
        <div class="filterMatrix-container">
        </div>
      </div>

      <div class="result-box filter-track">
        <h4>Track filters</h4>
        <div class="filter-content">
        
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
        <button class="fade-button reset-button _matrix">Reset</button>
        <div class="track-popup column-cell">
          <ul class="_cell">

          </ul>
          <ul>
            <li>
              <label class="switch"><input type="checkbox" name="column-switch"><span class="slider round"></span><span class="switch-label">Column</span></label>
            </li>
          </ul>
          <ul>
            <li>
              <label class="switch"><input type="checkbox" name="row-switch"><span class="slider round"></span><span class="switch-label">Row</span></label>
            </li>
          </ul>
          <ul>
            <li>
              <label class="switch"><input type="checkbox" name="all-switch"><span class="slider round"></span><span class="switch-label">All</span></label>
            </li>
          </ul>
        </div>
        <div class="hidebox"></div>
        <div class="matrix-container">
        </div>
      </div>

      <div class="result-box">
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
  );

  return $html;
}

1;
