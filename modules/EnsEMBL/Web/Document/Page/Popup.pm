# $Id$

package EnsEMBL::Web::Document::Page::Popup;

use strict;

use base qw(EnsEMBL::Web::Document::Page::Common);

sub _initialize_HTML {
  my $self = shift;

  return $self->_initialize_JSON if $self->renderer->{'_modal_dialog_'};
  
  $self->include_navigation(1);
  
  # General layout for popup pages
  $self->add_head_elements(qw(
    title      EnsEMBL::Web::Document::HTML::Title
    stylesheet EnsEMBL::Web::Document::HTML::Stylesheet
    links      EnsEMBL::Web::Document::HTML::Links
    meta       EnsEMBL::Web::Document::HTML::Meta
  ));

  $self->add_body_elements(qw(
    logo            EnsEMBL::Web::Document::HTML::Logo
    global_context  EnsEMBL::Web::Document::HTML::ModalTabs
    local_context   EnsEMBL::Web::Document::HTML::LocalContext
    content         EnsEMBL::Web::Document::HTML::Content
    body_javascript EnsEMBL::Web::Document::HTML::BodyJavascript
  ));
}

sub _initialize_JSON {
  my $self = shift;
  
  $self->add_body_elements(qw(
    global_context EnsEMBL::Web::Document::HTML::ModalTabs
    local_context  EnsEMBL::Web::Document::HTML::LocalContext
    content        EnsEMBL::Web::Document::HTML::Content
  ));
}

sub panel_type {
  return '<input type="hidden" class="panel_type" value="ModalContent" />' if $_[0]->renderer->{'_modal_dialog_'};
}

1;
