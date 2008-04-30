package EnsEMBL::Web::Document::Popup;

use strict;
use EnsEMBL::Web::Document::Common;

our @ISA = qw(EnsEMBL::Web::Document::Common);

use Data::Dumper qw(Dumper);

sub _initialize_HTML {
  my $self = shift;

## General layout for popup pages...

  $self->add_head_elements qw(
    title      EnsEMBL::Web::Document::HTML::Title
    stylesheet EnsEMBL::Web::Document::HTML::Stylesheet
    javascript EnsEMBL::Web::Document::HTML::Javascript
    rss        EnsEMBL::Web::Document::HTML::RSS
    meta       EnsEMBL::Web::Document::HTML::Meta
  );

  $self->add_body_elements qw(
    logo           EnsEMBL::Web::Document::HTML::Empty
    search_box     EnsEMBL::Web::Document::HTML::Empty
    breadcrumbs    EnsEMBL::Web::Document::HTML::Empty
    tools          EnsEMBL::Web::Document::HTML::Empty
    content        EnsEMBL::Web::Document::HTML::Content
    global_context EnsEMBL::Web::Document::HTML::Empty
    local_context  EnsEMBL::Web::Document::HTML::Empty
    release        EnsEMBL::Web::Document::HTML::Empty
    copyright      EnsEMBL::Web::Document::HTML::Empty
    body_javascript EnsEMBL::Web::Document::HTML::BodyJavascript
  );
  $self->call_child_functions( 'common_page_elements' );

  $self->_common_HTML;
  $self->_script_HTML;
  $self->helplink->kw = $ENV{'ENSEMBL_SCRIPT'}.';se=1';
  $self->rss->add( '/common/rss.xml', 'Ensembl website news feed', 'rss' );
  $self->call_child_functions( 'extra_configuration' );
}

1;
