package EnsEMBL::Web::Document::Static;

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::OrderedTree;

use base qw(EnsEMBL::Web::Document::Common);

sub _initialize {
  my $self = shift;

## General layout for static pages...
  $self->add_head_elements qw(
    title      EnsEMBL::Web::Document::HTML::Title
    stylesheet EnsEMBL::Web::Document::HTML::Stylesheet
    links      EnsEMBL::Web::Document::HTML::Links
    javascript EnsEMBL::Web::Document::HTML::Javascript
    meta       EnsEMBL::Web::Document::HTML::Meta
  );
    #iehover    EnsEMBL::Web::Document::HTML::IEHoverHack
  $self->add_body_elements qw(
    logo            EnsEMBL::Web::Document::HTML::Logo
    search_box      EnsEMBL::Web::Document::HTML::SearchBox
    breadcrumbs     EnsEMBL::Web::Document::HTML::BreadCrumbs
    tools           EnsEMBL::Web::Document::HTML::ToolLinks
    content         EnsEMBL::Web::Document::HTML::Content
    global_context  EnsEMBL::Web::Document::HTML::GlobalContext
  );
  if( $self->include_navigation ) {
    $self->add_body_elements qw(
      local_context  EnsEMBL::Web::Document::HTML::DocsMenu
      local_tools    EnsEMBL::Web::Document::HTML::Empty
    );
  }
  $self->add_body_elements qw(
    copyright      EnsEMBL::Web::Document::HTML::Copyright
    footerlinks    EnsEMBL::Web::Document::HTML::FooterLinks
    body_javascript EnsEMBL::Web::Document::HTML::BodyJavascript
  );

  $self->call_child_functions( 'common_page_elements','static_page_elements' );
  $self->_common_HTML();

  $self->call_child_functions( 'extra_configuration' );
}

1;
