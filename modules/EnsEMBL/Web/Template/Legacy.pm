=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

use HTML::Entities qw(encode_entities);

sub init {
  my $self = shift;
  $self->{'main_class'}       = 'main';
  $self->{'lefthand_menu'}    = 1;
  $self->{'has_species_bar'}  = $self->hub->species && $self->hub->species !~ /multi|common/i ? 1 : 0;
  $self->{'has_tabs'}         = $self->hub->controller->configuration->has_tabs;
  $self->add_head;
  $self->add_body;
}

sub add_head {
  my $self = shift;
  my $page = $self->page;
  
  $page->add_head_elements(qw(
    title           EnsEMBL::Web::Document::Element::Title
    stylesheet      EnsEMBL::Web::Document::Element::Stylesheet
    links           EnsEMBL::Web::Document::Element::Links
    meta            EnsEMBL::Web::Document::Element::Meta
    prefetch        EnsEMBL::Web::Document::Element::Prefetch
    head_javascript EnsEMBL::Web::Document::Element::HeadJavascript
  ));
}

sub add_body {
  my $self = shift;
  my $page = $self->page;
  
  $page->add_body_elements(qw(
    logo             EnsEMBL::Web::Document::Element::Logo
    account          EnsEMBL::Web::Document::Element::AccountLinks
    search_box       EnsEMBL::Web::Document::Element::SearchBox
    tools            EnsEMBL::Web::Document::Element::ToolLinks
  ));

  if ($self->{'has_species_bar'}) { 
    $page->add_body_elements(qw(
      species_bar      EnsEMBL::Web::Document::Element::SpeciesBar
    ));
  }
  
  if ($self->{'has_tabs'}) { 
    $page->add_body_elements(qw(
      tabs            EnsEMBL::Web::Document::Element::Tabs
    ));
  }
  
  $page->add_body_elements(qw(
    navigation       EnsEMBL::Web::Document::Element::Navigation
    tool_buttons     EnsEMBL::Web::Document::Element::ToolButtons
    summary          EnsEMBL::Web::Document::Element::Summary
    content          EnsEMBL::Web::Document::Element::Content
    modal            EnsEMBL::Web::Document::Element::Modal
    acknowledgements EnsEMBL::Web::Document::Element::Acknowledgements
    copyright        EnsEMBL::Web::Document::Element::Copyright
    footerlinks      EnsEMBL::Web::Document::Element::FooterLinks
    fatfooter        EnsEMBL::Web::Document::Element::FatFooter
    tmp_message      EnsEMBL::Web::Document::Element::TmpMessage
    body_javascript  EnsEMBL::Web::Document::Element::BodyJavascript
  ));
}

sub render {
  my ($self, $elements) = @_;
  my $hub = $self->hub;
  my $HTML;

  $HTML .= $self->render_masthead($elements);
  $HTML .= $self->render_content($elements);
  $HTML .= $self->render_footer($elements);
  $HTML .= $self->render_page_end($elements);

  return $HTML;
}


sub render_masthead {
  my ($self, $elements) = @_;

  ## MASTHEAD & GLOBAL NAVIGATION
  my $masthead_class = '';
  if ($self->{'has_species_bar'}) {
    $masthead_class = $self->{'has_tabs'} ? ' bar_and_tabs' : ' bar_only';
  }
  elsif ($self->{'has_tabs'}) {
    $masthead_class = ' tabs_only';
  }

  return qq(
  <div id="min_width_container">
    <div id="min_width_holder">
    
    <!-- Announcement Banner -->    
        $elements->{'tmp_message'}->{'announcement_banner_message'}
    <!-- /Announcement Banner -->

      <div id="masthead" class="js_panel$masthead_class">
        <input type="hidden" class="panel_type" value="Masthead" />
        <div class="logo_holder">$elements->{'logo'}</div>
        <div class="mh print_hide">
          <div class="account_holder">$elements->{'account'}</div>
          <div class="tools_holder">$elements->{'tools'}</div>
          <div class="search_holder print_hide">$elements->{'search_box'}</div>
        </div>
  );
}

sub render_content {
  my ($self, $elements) = @_;
  my $hub = $self->hub;
  my $page = $self->page;

  ## LOCAL NAVIGATION & MAIN CONTENT
  my $sp_bar      = $elements->{'species_bar'} ? qq(<div class="spbar_holder">$elements->{'species_bar'}</div>) : '';
  my $tabs        = $elements->{'tabs'} ? qq(<div class="tabs_holder print_hide">$elements->{'tabs'}</div>) : '';

  my $icons       = $page->icon_bar if $page->can('icon_bar');  
  my $panel_type  = $page->can('panel_type') ? $page->panel_type : '';
  my $main_holder = $panel_type ? qq(<div id="main_holder" class="js_panel">$panel_type) : '<div id="main_holder">';
  my $main_class  = $self->{'main_class'};  

  my $nav;
  my $nav_class   = $page->isa('EnsEMBL::Web::Document::Page::Configurator') ? 'cp_nav' : 'nav';
  if ($self->{'lefthand_menu'}) {
    $nav = qq(
      <div id="page_nav_wrapper">
        <div id="page_nav" class="$nav_class print_hide js_panel floating">
          $elements->{'navigation'}
          $elements->{'tool_buttons'}
          $elements->{'acknowledgements'}
          <p class="invisible">.</p>
        </div>
      </div>
    );
  }

  return qq(
        $sp_bar
        $tabs
        $icons
      </div>

      $main_holder
      $nav

      <div id="$main_class">
          $elements->{'breadcrumbs'}
          $elements->{'message'}
          $elements->{'content'}
      </div>
  );
}

sub render_footer {
  my ($self, $elements) = @_;
  my $hub = $self->hub;
  my $page = $self->page;

  my $footer_id = $self->{'lefthand_menu'} ? 'footer' : 'wide-footer';
  my $html = qq(
        <div id="$footer_id">
          <div class="column-wrapper">$elements->{'copyright'}$elements->{'footerlinks'}
            <p class="invisible">.</p>
          </div>
          <div class="column-wrapper">$elements->{'fatfooter'}
            <p class="invisible">.</p>
          </div>
        </div>
  );

  if ($self->{'show_banner'}) {
    $html .= $elements->{'bottom_banner'};
  }
  return $html;
}

sub render_page_end {
  my ($self, $elements) = @_;
  my $hub = $self->hub;
  my $page = $self->page;

  ## JAVASCRIPT AND OTHER STUFF THAT NEEDS TO BE HIDDEN AT BOTTOM OF PAGE
  my $species_path        = $hub->species_defs->species_path;
  my $gdpr_version        = $hub->species_defs->GDPR_VERSION;
  my $gdpr_policy_url     = $hub->species_defs->GDPR_POLICY_URL;
  my $gdpr_terms_url      = $hub->species_defs->GDPR_TERMS_URL;
  my $gdpr_cookie_name    = $hub->species_defs->GDPR_COOKIE_NAME;
  my $species_display_name = $hub->species_defs->SPECIES_DISPLAY_NAME;
  my $max_region_length   = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1);
  my $ensembl_image_root  = $hub->species_defs->ENSEMBL_IMAGE_ROOT;
  my $ensembl_species_image  = '/i/species/' . $hub->species_defs->SPECIES_IMAGE . '.png';
  my $core_params         = $hub->core_params || {};
  my $core_params_html = join('',map {
      $v = encode_entities($core_params->{$_});
      qq(<input type="hidden" name="$_" value="$v" />)
    } keys %$core_params);
  return qq(
      </div>
    </div>
  </div>
  <form id="core_params" action="#" style="display:none">
    <fieldset>$core_params_html</fieldset>
  </form>
  <input type="hidden" id="species_path" name="species_path" value="$species_path" />
  <input type="hidden" id="gdpr_version" name="gdpr_version" value="$gdpr_version" />
  <input type="hidden" id="gdpr_policy_url" name="gdpr_policy_url" value="$gdpr_policy_url" />
  <input type="hidden" id="gdpr_terms_url" name="gdpr_terms_url" value="$gdpr_terms_url" />
  <input type="hidden" id="gdpr_cookie_name" name="gdpr_cookie_name" value="$gdpr_cookie_name" />
  <input type="hidden" id="species_common_name" name="species_common_name" value="$species_display_name" />
  <input type="hidden" id="ensembl_image_root" name="ensembl_image_root" value="$ensembl_image_root" />
  <input type="hidden" id="max_region_length" name="max_region_length" value="$max_region_length" />
  <input type="hidden" id="ensembl_species_image" name="ensembl_species_image" value="$ensembl_species_image" />
    $elements->{'modal'}
    $elements->{'tmp_message'}->{'popup_message'}
    $elements->{'body_javascript'}
  );
  
}

1;
