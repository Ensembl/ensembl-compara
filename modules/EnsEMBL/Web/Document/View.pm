package EnsEMBL::Web::Document::View;

use EnsEMBL::Web::Document::Dynamic;
our @ISA = qw(EnsEMBL::Web::Document::Dynamic);

{

sub _initialize_HTML {
  my $self = shift;
  #$self->SUPER::_initialize_HTML(@_);

  $self->add_head_elements qw(
    title      EnsEMBL::Web::Document::HTML::Title
    stylesheet EnsEMBL::Web::Document::HTML::Stylesheet
    javascript EnsEMBL::Web::Document::HTML::Javascript
    meta       EnsEMBL::Web::Document::HTML::Meta
  );
    #iehover    EnsEMBL::Web::Document::HTML::IEHoverHack
  $self->add_body_elements qw(
    javascript_div EnsEMBL::Web::Document::HTML::JavascriptDiv
    masthead   EnsEMBL::Web::Document::HTML::MastHead
    searchbox  EnsEMBL::Web::Document::HTML::SearchBox
    release    EnsEMBL::Web::Document::HTML::Release
    helplink   EnsEMBL::Web::Document::HTML::HelpLink
    html_start EnsEMBL::Web::Document::HTML::HTML_Block
    menu       EnsEMBL::Web::Document::HTML::Menu
    view       EnsEMBL::Web::Document::HTML::View
    copyright  EnsEMBL::Web::Document::HTML::Copyright
    html_end   EnsEMBL::Web::Document::HTML::HTML_Block
  );

  $self->call_child_functions( 'common_page_elements','dynamic_page_elements' );
  $self->_prof( "page elements configured" );
  $self->_common_HTML();
  $self->_prof( "common HTML called" );
  $self->_script_HTML();
  $self->_prof( "script HTML called" );
  $self->helplink->kw = $ENV{'ENSEMBL_SCRIPT'}.';se=1';
## Let us set up the search box...
  $self->searchbox->sp_common  = $self->species_defs->SPECIES_COMMON_NAME;
#  --- First the search index drop down
  $self->_prof( "page decs configured" );

  $self->javascript->add_source('/js/core42.js');
  $self->javascript->add_source('/js/new_drag_imagemap.js');
  $self->javascript->add_source('/js/help.js');
  $self->javascript->add_source('/js/new_support.js');

  $self->_prof( "search box set up configured" );

#  --- and the search box links...

  $self->call_child_functions( 'extra_configuration' );
  $self->call_child_functions( 'common_menu_items', 'dynamic_menu_items' );

  $self->_prof( "menu items configured" );

}

sub render {
  my ($self, $page) = @_;
  $self->_render_head_and_body_tag;
  foreach my $R ( @{$self->{'body_order'}} ) {
    my $attr = $R->[0];
    $self->$attr->render($page);
  }
  $self->_render_close_body_tag;
}


}


1;
