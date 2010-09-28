# $Id$

package EnsEMBL::Web::Document::Page::Static;

use strict;

use base qw(EnsEMBL::Web::Document::Page);

sub initialize_HTML {
  my $self = shift;

  # General layout for static pages
  $self->add_head_elements(qw(
    title      EnsEMBL::Web::Document::Element::Title
    stylesheet EnsEMBL::Web::Document::Element::Stylesheet
    javascript EnsEMBL::Web::Document::Element::Javascript
    links      EnsEMBL::Web::Document::Element::Links
    meta       EnsEMBL::Web::Document::Element::Meta
  ));
  
  $self->add_body_elements(qw(
    logo        EnsEMBL::Web::Document::Element::Logo
    search_box  EnsEMBL::Web::Document::Element::SearchBox
    tools       EnsEMBL::Web::Document::Element::ToolLinks
    breadcrumbs EnsEMBL::Web::Document::Element::BreadCrumbs
  ));
  
  $self->add_body_elements(qw(navigation EnsEMBL::Web::Document::Element::DocsMenu)) if $self->include_navigation;
  
  $self->add_body_elements(qw(
    content         EnsEMBL::Web::Document::Element::Content
    modal           EnsEMBL::Web::Document::Element::Modal
    copyright       EnsEMBL::Web::Document::Element::Copyright
    footerlinks     EnsEMBL::Web::Document::Element::FooterLinks
    body_javascript EnsEMBL::Web::Document::Element::BodyJavascript
  ));
}

1;
