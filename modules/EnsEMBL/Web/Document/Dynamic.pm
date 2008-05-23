package EnsEMBL::Web::Document::Dynamic;

use strict;
use EnsEMBL::Web::Document::Common;

our @ISA = qw(EnsEMBL::Web::Document::Common);

use Data::Dumper qw(Dumper);

sub set_title {
  my $self  = shift;
  my $title = shift;
  $self->title->set( $self->species_defs->ENSEMBL_SITE_NAME.' release '.$self->species_defs->ENSEMBL_VERSION.': '.$self->species_defs->SPECIES_BIO_NAME.' '.$title );
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

  $self->add_head_elements qw(
    title      EnsEMBL::Web::Document::HTML::Title
    stylesheet EnsEMBL::Web::Document::HTML::Stylesheet
    javascript EnsEMBL::Web::Document::HTML::Javascript
    rss        EnsEMBL::Web::Document::HTML::RSS
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
    local_context   EnsEMBL::Web::Document::HTML::LocalContext
    local_tools     EnsEMBL::Web::Document::HTML::LocalTools
    copyright       EnsEMBL::Web::Document::HTML::Copyright
    footerlinks     EnsEMBL::Web::Document::HTML::FooterLinks
    body_javascript EnsEMBL::Web::Document::HTML::BodyJavascript
  );

  $self->call_child_functions( 'common_page_elements','dynamic_page_elements' );
  $self->_prof( "page elements configured" );
  $self->_common_HTML();
  $self->_prof( "common HTML called" );
  $self->_script_HTML();
  $self->_prof( "script HTML called" );
#  $self->helplink->kw = $ENV{'ENSEMBL_SCRIPT'};
  $self->rss->add( '/common/rss.xml', 'Ensembl website news feed', 'rss' );
## Let us set up the search box...
#  $self->search_box->sp_common  = $self->species_defs->SPECIES_COMMON_NAME;
#  --- First the search index drop down
  $self->_prof( "page decs configured" );
  if( $ENV{'ENSEMBL_SPECIES'} ne 'Multi' && $ENV{'ENSEMBL_SPECIES'} ne 'common' ) { # If we are in static content for a species
#    foreach my $K ( sort @{($self->species_defs->ENSEMBL_SEARCH_IDXS)||[]} ) {
#      $self->searchbox->add_index( $K );
#    }
    ## Now grab the default search links for the species
#    my $T = $self->species_defs->SEARCH_LINKS || {};
#    my $flag = 0;
#    my $regexp = '^('.$ENV{'ENSEMBL_SCRIPT'}.'\d+)_URL';
#    foreach my $K ( sort keys %$T ) {
#      if( $K =~ /$regexp/i ) {
#        $flag = 1;
#        $self->searchbox->add_link( $T->{$K}, $T->{$1."_TEXT"} );
#      }
#    }
#    unless($flag) { 
# #     foreach my $K ( sort keys %$T ) {
#        if( $K =~ /DEFAULT(\d)_URL/ ) {
#          $self->searchbox->add_link( $T->{$K}, $T->{"DEFAULT$1"."_TEXT"} );
#        }
#      }
#    }
#  } else { # If we are in general static content...
#    ## Grab all the search indexes...
#    foreach my $K ( $self->species_defs->all_search_indexes ) {
##      $self->searchbox->add_index( $K );
#    }
    ## Note we have no example links here!!
  }

  $self->_prof( "search box set up configured" );

#  --- and the search box links...

  $self->call_child_functions( 'extra_configuration' );
#  $self->call_child_functions( 'common_menu_items', 'dynamic_menu_items' );

  $self->_prof( "menu items configured" );
}

1;
