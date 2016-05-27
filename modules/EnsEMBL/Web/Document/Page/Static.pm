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

package EnsEMBL::Web::Document::Page::Static;

use strict;

use base qw(EnsEMBL::Web::Document::Page);

sub initialize_HTML {
  my $self = shift;

  my $here = $ENV{'REQUEST_URI'};
  my $has_nav = 0;
  my $template = 'Legacy::Wide';

  if ($here =~ /Doxygen\/index.html/ || ($here =~ /^\/info/ && $here !~ /Doxygen/)) {
    ## Documentation pages, excluding ones created by Doxygen script
    $template = 'Legacy';
    $has_nav = 1; 
  }
  $self->include_navigation($has_nav);
  $self->hub->template = $template;

  # General layout for static pages
  $self->add_head_elements(qw(
    title      EnsEMBL::Web::Document::Element::Title
    stylesheet EnsEMBL::Web::Document::Element::Stylesheet
    javascript EnsEMBL::Web::Document::Element::Javascript
    links      EnsEMBL::Web::Document::Element::Links
    meta       EnsEMBL::Web::Document::Element::Meta
    prefetch   EnsEMBL::Web::Document::Element::Prefetch
  ));
  
  $self->add_body_elements(qw(
    logo            EnsEMBL::Web::Document::Element::Logo
    account         EnsEMBL::Web::Document::Element::AccountLinks
    search_box      EnsEMBL::Web::Document::Element::SearchBox
    tools           EnsEMBL::Web::Document::Element::ToolLinks
  ));

  if ($has_nav) {
    $self->add_body_elements(qw(
      tabs            EnsEMBL::Web::Document::Element::StaticTabs
      navigation      EnsEMBL::Web::Document::Element::StaticNav
    ));
  }

  $self->add_body_elements(qw(
    breadcrumbs     EnsEMBL::Web::Document::Element::BreadCrumbs
    content         EnsEMBL::Web::Document::Element::Content
    modal           EnsEMBL::Web::Document::Element::Modal
    copyright       EnsEMBL::Web::Document::Element::Copyright
    footerlinks     EnsEMBL::Web::Document::Element::FooterLinks
    fatfooter       EnsEMBL::Web::Document::Element::FatFooter
    body_javascript EnsEMBL::Web::Document::Element::BodyJavascript
  ));
}

1;
