# $Id$

package EnsEMBL::Web::Document::Page::Dynamic;

use strict;

use base qw(EnsEMBL::Web::Document::Page::Common);

sub _initialize_HTML {
  my $self = shift;

  $self->include_navigation(1);
  
  # General layout for dynamic pages
  $self->add_head_elements(qw(
    title      EnsEMBL::Web::Document::HTML::Title
    stylesheet EnsEMBL::Web::Document::HTML::Stylesheet
    javascript EnsEMBL::Web::Document::HTML::Javascript
    links      EnsEMBL::Web::Document::HTML::Links
    meta       EnsEMBL::Web::Document::HTML::Meta
  ));
  
  $self->add_body_elements(qw(
    logo             EnsEMBL::Web::Document::HTML::Logo
    search_box       EnsEMBL::Web::Document::HTML::SearchBox
    breadcrumbs      EnsEMBL::Web::Document::HTML::BreadCrumbs
    tools            EnsEMBL::Web::Document::HTML::ToolLinks
    content          EnsEMBL::Web::Document::HTML::Content
    global_context   EnsEMBL::Web::Document::HTML::GlobalContext
    local_context    EnsEMBL::Web::Document::HTML::LocalContext
    modal_context    EnsEMBL::Web::Document::HTML::ModalContext
    local_tools      EnsEMBL::Web::Document::HTML::LocalTools
    acknowledgements EnsEMBL::Web::Document::HTML::Acknowledgements
    copyright        EnsEMBL::Web::Document::HTML::Copyright
    footerlinks      EnsEMBL::Web::Document::HTML::FooterLinks
    body_javascript  EnsEMBL::Web::Document::HTML::BodyJavascript
  ));
  
  $self->_common_HTML;
}

sub _initialize_Text {
  my $self = shift; 
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::Text::Content));
  $self->_init;
}

sub _initialize_Excel {
  my $self = shift; 
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::Excel::Content));
  $self->_init;
}

sub _initialize_XML {
  my $self = shift;
  my $doctype_version = shift;
  
  if (!$doctype_version) {
    $doctype_version = 'xhtml';
    warn '[WARN] No DOCTYPE_VERSION (hence DTD) specified. Defaulting to xhtml, which is probably not what is required.';
  }
  
  $self->set_doc_type('XML', $doctype_version);
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::XML::Content));
  $self->_init;
}

sub _initialize_TextGz { shift->_initialize_Text; }
sub _initialize_DAS    { shift->_initialize_XML(@_); }

1;
