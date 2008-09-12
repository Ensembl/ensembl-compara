package EnsEMBL::Web::Document::Popup;

use strict;
use EnsEMBL::Web::Document::Common;

our @ISA = qw(EnsEMBL::Web::Document::Common);

use Data::Dumper qw(Dumper);

sub _initialize_HTML {
  my $self = shift;

  $self->include_navigation(1);
## General layout for popup pages...

  $self->add_head_elements qw(
    title      EnsEMBL::Web::Document::HTML::Title
    stylesheet EnsEMBL::Web::Document::HTML::Stylesheet
    javascript EnsEMBL::Web::Document::HTML::Javascript
    rss        EnsEMBL::Web::Document::HTML::RSS
    meta       EnsEMBL::Web::Document::HTML::Meta
  );

  $self->add_body_elements qw(
    logo            EnsEMBL::Web::Document::HTML::Logo
    search_box      EnsEMBL::Web::Document::HTML::LoggedIn
    breadcrumbs     EnsEMBL::Web::Document::HTML::Empty
    tools           EnsEMBL::Web::Document::HTML::CloseCP
    content         EnsEMBL::Web::Document::HTML::Content
    global_context  EnsEMBL::Web::Document::HTML::GlobalContext
    local_context   EnsEMBL::Web::Document::HTML::LocalContext
    local_tools     EnsEMBL::Web::Document::HTML::LocalTools
    copyright       EnsEMBL::Web::Document::HTML::Empty
    footerlinks     EnsEMBL::Web::Document::HTML::Empty
    body_javascript EnsEMBL::Web::Document::HTML::BodyJavascript
  );
  $self->call_child_functions( 'common_page_elements' );

  $self->timer_push( "page elements configured" );
  $self->_common_HTML();
  $self->timer_push( "common HTML called" );
  $self->_script_HTML();
  $self->timer_push( "script HTML called" );
  $self->rss->add( '/common/rss.xml', 'Ensembl website news feed', 'rss' );
  $self->timer_push( "page decs configured" );

  $self->call_child_functions( 'extra_configuration' );

  $self->timer_push( "menu items configured" );

}

1;
