# $Id$

package EnsEMBL::Web::Document::Page::Popup;

use strict;

use base qw(EnsEMBL::Web::Document::Page);

sub initialize_HTML {
  my $self = shift;

  return $self->initialize_JSON if $self->renderer->{'_modal_dialog_'};
  
  $self->include_navigation(1);
  
  # General layout for popup pages
  $self->add_head_elements(qw(
    title      EnsEMBL::Web::Document::Element::Title
    stylesheet EnsEMBL::Web::Document::Element::Stylesheet
    links      EnsEMBL::Web::Document::Element::Links
    meta       EnsEMBL::Web::Document::Element::Meta
  ));

  $self->add_body_elements(qw(
    logo            EnsEMBL::Web::Document::Element::Logo
    tabs            EnsEMBL::Web::Document::Element::ModalTabs
    navigation      EnsEMBL::Web::Document::Element::Navigation
    tool_buttons    EnsEMBL::Web::Document::Element::ModalButtons
    content         EnsEMBL::Web::Document::Element::Content
    body_javascript EnsEMBL::Web::Document::Element::BodyJavascript
  ));
}

sub initialize_JSON {
  my $self = shift;
  
  $self->add_body_elements(qw(
    tabs         EnsEMBL::Web::Document::Element::ModalTabs
    navigation   EnsEMBL::Web::Document::Element::Navigation
    tool_buttons EnsEMBL::Web::Document::Element::ModalButtons
    content      EnsEMBL::Web::Document::Element::Content
  ));
}

sub panel_type {
  return '<input type="hidden" class="panel_type" value="ModalContent" />' if $_[0]->renderer->{'_modal_dialog_'};
}

1;
