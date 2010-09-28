# $Id$

package EnsEMBL::Web::Document::Page::Static;

use strict;

use base qw(EnsEMBL::Web::Document::Page::Common);

sub _initialize {}

sub initialize {
  my $self = shift;

  # General layout for static pages
  $self->add_head_elements(qw(
    title      EnsEMBL::Web::Document::HTML::Title
    stylesheet EnsEMBL::Web::Document::HTML::Stylesheet
    javascript EnsEMBL::Web::Document::HTML::Javascript
    links      EnsEMBL::Web::Document::HTML::Links
    meta       EnsEMBL::Web::Document::HTML::Meta
  ));
  
  $self->add_body_elements(qw(
    logo        EnsEMBL::Web::Document::HTML::Logo
    search_box  EnsEMBL::Web::Document::HTML::SearchBox
    tools       EnsEMBL::Web::Document::HTML::ToolLinks
    breadcrumbs EnsEMBL::Web::Document::HTML::BreadCrumbs
  ));
  
  $self->add_body_elements(qw(local_context EnsEMBL::Web::Document::HTML::DocsMenu)) if $self->include_navigation;
  
  $self->add_body_elements(qw(
    content         EnsEMBL::Web::Document::HTML::Content
    modal_context   EnsEMBL::Web::Document::HTML::ModalContext
    copyright       EnsEMBL::Web::Document::HTML::Copyright
    footerlinks     EnsEMBL::Web::Document::HTML::FooterLinks
    body_javascript EnsEMBL::Web::Document::HTML::BodyJavascript
  ));
  
  $self->_init;
}

1;
