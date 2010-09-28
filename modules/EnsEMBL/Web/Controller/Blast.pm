# $Id$

package EnsEMBL::Web::Controller::Blast;

use strict;

use base qw(EnsEMBL::Web::Controller);

sub renderer_type   { return 'Apache';    }
sub content :lvalue { $_[0]->{'content'}; }

sub init {
  my $self = shift;
  my $page = $self->page;
  
  $page->include_navigation(0);
  
  $page->add_head_elements(qw(
    title      EnsEMBL::Web::Document::HTML::Title
    stylesheet EnsEMBL::Web::Document::HTML::Stylesheet
    javascript EnsEMBL::Web::Document::HTML::Javascript
    links      EnsEMBL::Web::Document::HTML::Links
    meta       EnsEMBL::Web::Document::HTML::Meta
  ));
  
  $page->add_body_elements(qw(
    logo             EnsEMBL::Web::Document::HTML::Logo
    search_box       EnsEMBL::Web::Document::HTML::SearchBox
    tools            EnsEMBL::Web::Document::HTML::ToolLinks
    content          EnsEMBL::Web::Document::HTML::Content
    modal_context    EnsEMBL::Web::Document::HTML::ModalContext
    acknowledgements EnsEMBL::Web::Document::HTML::Acknowledgements
    copyright        EnsEMBL::Web::Document::HTML::Copyright
    footerlinks      EnsEMBL::Web::Document::HTML::FooterLinks
    body_javascript  EnsEMBL::Web::Document::HTML::BodyJavascript
  ));
  
  $page->_init;
}

1;
