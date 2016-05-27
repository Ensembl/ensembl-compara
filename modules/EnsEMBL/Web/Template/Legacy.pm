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

package EnsEMBL::Web::Template::Legacy;

### Legacy page template, used by standard HTML pages

use parent qw(EnsEMBL::Web::Template);

sub init {
  my $self = shift;
  $self->{'main_class'} = 'main';
}

sub render {
  my $self = shift;
  my $hub = $self->hub;
  my $page = $self->page;
  my $elements = $self->elements;

  my $HTML;

  ## MASTHEAD & GLOBAL NAVIGATION
  $HTML .= qq(
  <div id="min_width_container">
    <div id="min_width_holder">
      <div id="masthead" class="js_panel">
        <input type="hidden" class="panel_type" value="Masthead" />
        <div class="logo_holder">$elements->{'logo'}</div>
        <div class="mh print_hide">
          <div class="account_holder">$elements->{'account'}</div>
          <div class="tools_holder">$elements->{'tools'}</div>
          <div class="search_holder print_hide">$elements->{'search_box'}</div>
        </div>
);

  ## LOCAL NAVIGATION & MAIN CONTENT
  my $tabs        = $elements->{'tabs'} ? qq(<div class="tabs_holder print_hide">$elements->{'tabs'}</div>) : '';
  my $icons       = $page->icon_bar if $page->can('icon_bar');  
  my $panel_type  = $page->can('panel_type') ? $page->panel_type : '';
  my $main_holder = $panel_type ? qq(<div id="main_holder" class="js_panel">$panel_type) : '<div id="main_holder">';
  my $main_class  = $self->{'main_class'} || $page->main_class;  

  my $nav;
  my $nav_class   = $page->isa('EnsEMBL::Web::Document::Page::Configurator') ? 'cp_nav' : 'nav';
  if ($page->include_navigation) {
    $nav = qq(<div id="page_nav_wrapper">
        <div id="page_nav" class="$nav_class print_hide js_panel slide-nav floating">
          $elements->{'navigation'}
          $elements->{'tool_buttons'}
          $elements->{'acknowledgements'}
          <p class="invisible">.</p>
        </div>
      </div>
    );
  }

  $HTML .= qq(
        $tabs
        $icons
      </div>

      $main_holder
      $nav

      <div id="$main_class">
          $elements->{'breadcrumbs'}
          $elements->{'message'}
          $elements->{'content'}
          $elements->{'mobile_nav'}
      </div>
);

  ## FOOTER
  my $footer_id = $page->include_navigation ? 'footer' : 'wide-footer';
  $HTML .= qq(
        <div id="$footer_id">
          <div class="column-wrapper">$elements->{'copyright'}$elements->{'footerlinks'}
            <p class="invisible">.</p>
          </div>
          <div class="column-wrapper">$elements->{'fatfooter'}
            <p class="invisible">.</p>
          </div>
        </div>
      </div>
    </div>
  </div>
);

  ## JAVASCRIPT AND OTHER STUFF THAT NEEDS TO BE HIDDEN AT BOTTOM OF PAGE
  my $species_path        = $hub->species_defs->species_path;
  my $species_common_name = $hub->species_defs->SPECIES_COMMON_NAME;
  my $max_region_length   = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1);
  my $core_params         = $hub->core_params || {};
  my $core_params_html    = join '',   map qq(<input type="hidden" name="$_" value="$core_params->{$_}" />), keys %$core_params;

  $HTML .= qq(
  <form id="core_params" action="#" style="display:none">
    <fieldset>$core_params_html</fieldset>
  </form>
  <input type="hidden" id="species_path" name="species_path" value="$species_path" />
  <input type="hidden" id="species_common_name" name="species_common_name" value="$species_common_name" />
  <input type="hidden" id="max_region_length" name="max_region_length" value="$max_region_length" />
  $elements->{'modal'}
  $elements->{'body_javascript'}
);

  return $HTML;
}

1;
