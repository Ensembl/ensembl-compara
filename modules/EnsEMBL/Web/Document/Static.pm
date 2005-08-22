package EnsEMBL::Web::Document::Static;

use strict;
use EnsEMBL::Web::Document::Common;
use CGI qw(escapeHTML);

our @ISA = qw(EnsEMBL::Web::Document::Common);

sub _initialize {
  my $self = shift;

## General layout for static pages...

  $self->add_head_elements qw(
    title      EnsEMBL::Web::Document::HTML::Title
    stylesheet EnsEMBL::Web::Document::HTML::Stylesheet
    meta       EnsEMBL::Web::Document::HTML::Meta
    javascript EnsEMBL::Web::Document::HTML::Javascript
  );

  $self->add_body_elements qw(
    masthead     EnsEMBL::Web::Document::HTML::MastHead
    searchbox    EnsEMBL::Web::Document::HTML::SearchBox
    content      EnsEMBL::Web::Document::HTML::Content
    copyright    EnsEMBL::Web::Document::HTML::Copyright
    menu         EnsEMBL::Web::Document::HTML::Menu
    release      EnsEMBL::Web::Document::HTML::Release
    helplink     EnsEMBL::Web::Document::HTML::HelpLink
  );

  $self->_common_HTML();

## Let us set up the search box...
  $self->searchbox->sp_common  = $self->species_defs->SPECIES_COMMON_NAME;

  if( $ENV{'ENSEMBL_SPECIES'} ) { # If we are in static content for a species
    foreach my $K ( sort @{($self->species_defs->ENSEMBL_SEARCH_IDXS)||[]} ) {
      $self->searchbox->add_index( $K );
    }
    my $T = $self->species_defs->SEARCH_LINKS || {};
    ## Now grab the default search links for the species
    foreach my $K ( sort keys %$T ) {
      if( $K =~ /DEFAULT(\d)_URL/ ) {
        $self->searchbox->add_link( $T->{$K}, $T->{"DEFAULT$1"."_TEXT"} );
      }
    }
  } else { # If we are in general static content...
    ## Grab all the search indexes...
    foreach my $K ( $self->species_defs->all_search_indexes ) {
      $self->searchbox->add_index( $K );
    }
    ## Note we have no example links here!!
  }

  $self->call_child_functions( 'extra_configuration' );
  $self->call_child_functions( 'common_menu_items', 'static_menu_items' );

#  $self->menu->add_entry ('links',
#   'href' => "/info/about/ensembl_powered.html",
#   'text' => 'Ensembl Empowererd',
#    'icon' => '/img/ensemblicon.gif'
#  );
}

1;
