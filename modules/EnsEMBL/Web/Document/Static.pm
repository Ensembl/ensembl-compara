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
    javascript EnsEMBL::Web::Document::HTML::Javascript
    rss        EnsEMBL::Web::Document::HTML::RSS
    meta       EnsEMBL::Web::Document::HTML::Meta
  );
    #iehover    EnsEMBL::Web::Document::HTML::IEHoverHack
  $self->add_body_elements qw(
    logo           EnsEMBL::Web::Document::HTML::Logo
    search_box     EnsEMBL::Web::Document::HTML::SearchBox
    breadcrumbs    EnsEMBL::Web::Document::HTML::BreadCrumbs
    tools          EnsEMBL::Web::Document::HTML::ToolLinks
    content        EnsEMBL::Web::Document::HTML::Content
    global_context EnsEMBL::Web::Document::HTML::Empty
    local_context  EnsEMBL::Web::Document::HTML::Empty
    local_tools    EnsEMBL::Web::Document::HTML::Empty
    #global_context EnsEMBL::Web::Document::HTML::GlobalContext
    #local_context  EnsEMBL::Web::Document::HTML::LocalContext
    copyright      EnsEMBL::Web::Document::HTML::Copyright
    footerlinks    EnsEMBL::Web::Document::HTML::FooterLinks
    body_javascript EnsEMBL::Web::Document::HTML::BodyJavascript
  );

  $self->call_child_functions( 'common_page_elements','static_page_elements' );
  $self->_common_HTML();

=pod
  $self->global_context->add_entry( 'caption' => 'Using this website', 'url'     => '/info/website/', 'code'   => 'web'   );
  $self->global_context->add_entry( 'caption' => 'Fetching the data',  'url'     => '/info/data/',    'code'   => 'data'  );
  $self->global_context->add_entry( 'caption' => 'Code documentation', 'url'     => '/info/docs/',    'code'   => 'code'  );
  $self->global_context->add_entry( 'caption' => 'About us',           'url'     => '/info/about/',   'code'   => 'about' );
  $self->global_context->active( 'code:' );
  my $tree = EnsEMBL::Web::OrderedTree->new();
  my @nodes = ();
  foreach(1..20) {
    $nodes[$_] = $tree->create_node( "n$_", { 'caption' => "Node $_", 'url' => '/info/' } );
  }
  $nodes[1]->append($nodes[2]);
  $nodes[1]->append($nodes[3]);
  $nodes[1]->append($nodes[4]);
  $nodes[1]->append($nodes[5]);
  $nodes[2]->append($nodes[6]);
  $nodes[2]->append($nodes[7]);
  $nodes[2]->append($nodes[8]);
  $nodes[3]->append($nodes[9]);
  $nodes[3]->append($nodes[10]);
  $nodes[3]->append($nodes[11]);
  $nodes[12]->append($nodes[13]);
  $nodes[12]->append($nodes[14]);
  $nodes[12]->append($nodes[15]);
  $nodes[12]->append($nodes[16]);
  $nodes[12]->append($nodes[17]);
  $nodes[18]->append($nodes[19]);
  $nodes[18]->append($nodes[20]);

  $self->local_context->tree( $tree );
  $self->local_context->active( "n15" );
  $self->local_context->caption( "Code documentation" );
=cut

## Let us set up the search box...
#  $self->searchbox->sp_common  = $self->species_defs->SPECIES_COMMON_NAME;

  $self->rss->add( '/common/rss.xml', 'Ensembl website news feed', 'rss' );
#  if( $ENV{'ENSEMBL_SPECIES'} ) { # If we are in static content for a species
#    foreach my $K ( sort @{($self->species_defs->ENSEMBL_SEARCH_IDXS)||[]} ) {
#      $self->searchbox->add_index( $K );
#    }
# use Data::Dumper;
# #warn Data::Dumper::Dumper( $self->species_defs->SEARCH_LINKS );
#    my $T = $self->species_defs->SEARCH_LINKS || {};
#    ## Now grab the default search links for the species
#    foreach my $K ( sort keys %$T ) {
#      if( $K =~ /DEFAULT(\d)_URL/ ) {
#        $self->searchbox->add_link( $T->{$K}, $T->{"DEFAULT$1"."_TEXT"} );
#      }
#    }
#  } else { # If we are in general static content...
#    ## Grab all the search indexes...
#    foreach my $K ( $self->species_defs->all_search_indexes ) {
#      $self->searchbox->add_index( $K );
#    }
#    ## Note we have no example links here!!
#  }

  # add handy-dandy collapsing menu script

  $self->call_child_functions( 'extra_configuration' );
#  $self->call_child_functions( 'common_menu_items', 'static_menu_items' );

#  $self->menu->add_entry ('links',
#   'href' => "/info/about/ensembl_powered.html",
#   'text' => 'Ensembl Empowererd',
#    'icon' => '/img/ensemblicon.gif'
#  );
}

1;
