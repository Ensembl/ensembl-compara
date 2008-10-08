package EnsEMBL::Web::Document::Dynamic;

use strict;
use EnsEMBL::Web::Document::Common;

our @ISA = qw(EnsEMBL::Web::Document::Common);

use Data::Dumper qw(Dumper);

sub set_title {
  my $self  = shift;
  my $title = shift;
  $self->title->set( $self->species_defs->ENSEMBL_SITE_NAME.' release '.$self->species_defs->ENSEMBL_VERSION.': '.$self->species_defs->SPECIES_BIO_SHORT.' '.$title );
}

sub _initialize_TextGz {
  my $self = shift; 
  $self->add_body_elements qw(
    content EnsEMBL::Web::Document::Text::Content
  );
  $self->_init();
}

sub _initialize_Text {
  my $self = shift; 
  $self->add_body_elements qw(
    content EnsEMBL::Web::Document::Text::Content
  );
  $self->_init();
}

sub _initialize_Excel {
  my $self = shift; 
  $self->add_body_elements qw(
    content EnsEMBL::Web::Document::Excel::Content
  );
  $self->_init();
}

sub _initialize_DAS {
  my $self = shift;
  $self->_initialize_XML(@_);
}
sub _initialize_XML {
  my $self = shift;
  my $doctype_version = shift;
  unless( $doctype_version ){
    $doctype_version = 'xhtml';
    warn( "[WARN] No DOCTYPE_VERSION (hence DTD) specified. ".
          "Defaulting to xhtml, which is probably not what is required.");
  }
  $self->set_doc_type('XML',$doctype_version);
  #$self->set_doc_type('XML','rss version="0.91"');
  $self->add_body_elements qw(
    content     EnsEMBL::Web::Document::XML::Content
  );
  $self->_init();
}

sub _initialize_HTML {
  my $self = shift;

## General layout for dynamic pages...

  $self->include_navigation(1);
  $self->add_head_elements qw(
    title      EnsEMBL::Web::Document::HTML::Title
    stylesheet EnsEMBL::Web::Document::HTML::Stylesheet
    javascript EnsEMBL::Web::Document::HTML::Javascript
    rss        EnsEMBL::Web::Document::HTML::RSS
    meta       EnsEMBL::Web::Document::HTML::Meta
  );
  $self->add_body_elements qw(
    logo            EnsEMBL::Web::Document::HTML::Logo
    search_box      EnsEMBL::Web::Document::HTML::SearchBox
    breadcrumbs     EnsEMBL::Web::Document::HTML::BreadCrumbs
    tools           EnsEMBL::Web::Document::HTML::ToolLinks
    content         EnsEMBL::Web::Document::HTML::Content
    global_context  EnsEMBL::Web::Document::HTML::GlobalContext
    local_context   EnsEMBL::Web::Document::HTML::LocalContext
    local_tools     EnsEMBL::Web::Document::HTML::LocalTools
    copyright       EnsEMBL::Web::Document::HTML::Copyright
    footerlinks     EnsEMBL::Web::Document::HTML::FooterLinks
    body_javascript EnsEMBL::Web::Document::HTML::BodyJavascript
  );

  $self->call_child_functions( 'common_page_elements','dynamic_page_elements' );
  $self->timer_push( "page elements configured" );
  $self->_common_HTML();
  $self->timer_push( "common HTML called" );
  $self->_script_HTML();
  $self->timer_push( "script HTML called" );
  $self->rss->add( '/common/rss.xml', 'Ensembl website news feed', 'rss' );
  $self->timer_push( "page decs configured" );

  $self->call_child_functions( 'extra_configuration' );
#  $self->call_child_functions( 'common_menu_items', 'dynamic_menu_items' );

  $self->timer_push( "menu items configured" );
}

1;
