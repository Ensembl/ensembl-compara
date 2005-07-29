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
    iehover    EnsEMBL::Web::Document::HTML::IEHoverHack
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

## Now the links on the left hand side....
  my $species = $ENV{'ENSEMBL_SPECIES'} && $ENV{'ENSEMBL_SPECIES'} ne 'Multi' ? $ENV{'ENSEMBL_SPECIES'} : 'default';
  my $species_m  = $species eq 'default' ? 'Multi' : $species;
  $self->menu->add_block( 'whattodo', 'bulleted', 'Use Ensembl to...' );
  $self->menu->add_entry( 'whattodo', 'href' => "/$species_m/blastview", 'text'=>'Run a BLAST search' );
  $self->menu->add_entry( 'whattodo', 'href'=>"/$species/".$self->species_defs->ENSEMBL_SEARCH, 'text'=>'Search Ensembl' );
  $self->menu->add_entry( 'whattodo', 'href'=>"/$species_m/martview", 'text'=>'Data mining [BioMart]', 'icon' => '/img/biomarticon.gif' );
  $self->menu->add_entry( 'whattodo', 'href'=>"javascript:void(window.open('/default/helpview?se=1;kw=upload','helpview','width=700,height=550,resizable,scrollbars'))", 'text'=>'Upload your own data' );
  $self->menu->add_entry( 'whattodo', 'href'=>"/info/data/download.html",
			'text' => 'Download data');
  if( $species ne 'default' ) {
    $self->menu->add_entry( 'whattodo', 'href'=>"/$species/exportview", 'text' => 'Export data');
  }
#  $self->menu->add_entry( 'whattodo', 'href'=>"javascript:void(window.open('/perl/helpview?se=1;kw=karyoview','helpview','width=700,height=550,resizable,scrollbars'))", 'text'=>'Display your data on a karyotype diagram' );

  $self->menu->add_block( 'docs', 'bulleted', 'Docs and downloads' );
  $self->menu->add_entry( 'docs', 'href' => '/info/', 
			  'text'  => 'Information',
			  'title' => 'Information homepage');

  $self->menu->add_entry( 'docs', 'href' => '/whatsnew.html', 
			  'text'  => "What's New",
			  'title' => "Latest changes in Ensembl");

  $self->menu->add_entry( 'docs', 'href' => '/info/about/', 
			  'text'  => 'About Ensembl',
			  'title' => 'Introduction, Goals, Commitments, Citing Ensembl, Archive sites');
  $self->menu->add_entry( 'docs', 'href' => '/info/data/', 
			  'text'  => 'Ensembl data',
			  'title' => 'Downloads, Data import/export, Data mining, Data searching');
  $self->menu->add_entry( 'docs', 'href' => '/info/software/', 
			  'text'  => 'Software',
			  'title' => 'API, Installation, CVS, Versions');

# don't show species links on main home page
  unless( $ENV{'REQUEST_URI'} eq '/index.html' ) {
    $self->menu->add_block( 'species', 'bulleted', 'Select a species' );

  # do species popups from config
    my @group_order = ('Mammals', 'Chordates', 'Eukaryotes');
    my %spp_tree = (
      'Mammals'=>[{'label'=>'Mammals'}], 
      'Chordates'=>[{'label'=>'Other chordates'}], 
      'Eukaryotes'=>[{'label'=>'Other eukaryotes'}]
    );
    my @species_inconf = @{$self->species_defs->ENSEMBL_SPECIES};
    foreach my $sp (@species_inconf) {
      my $bio_name = $self->species_defs->other_species($sp, "SPECIES_BIO_NAME");
      my $group = $self->species_defs->other_species($sp, "SPECIES_GROUP");
      my $hash_ref = {'href'=>"/$sp/", 'text'=>"<i>$bio_name</i>", 'raw'=>1};
      push (@{$spp_tree{$group}}, $hash_ref);
    }
    foreach my $group (@group_order) {
      my $h_ref = shift(@{$spp_tree{$group}});
      my $text = $$h_ref{'label'};
      $self->menu->add_entry('species', 'href'=>'/', 'text'=>$text, 'options'=>$spp_tree{$group});
    }
  }

  $self->menu->add_block( 'links', 'bulleted', 'Other links' );
  $self->menu->add_entry( 'links', 'href' => '/', 'text' => 'Home' );
  my $map_link = '/sitemap.html';
  if (my $species = $ENV{'ENSEMBL_SPECIES'}) {
    $map_link = '/'.$species.$map_link;
  }
  $self->menu->add_entry( 'links', 'href' => $map_link, 'text' => 'Sitemap' );
  $self->menu->add_entry( 'links', 'href' => 'http://vega.sanger.ac.uk/', 'text' => 'Vega', 'icon' => '/img/vegaicon.gif', 
	'title' => "Vertebrate Genome Annotation" );
  $self->menu->add_entry( 'links', 'href' => 'http://trace.ensembl.org/', 'text' => 'Trace server', 
	'title' => "trace.ensembl.org - trace server" );

  if ($self->species_defs->ENSEMBL_SITE_NAME eq 'Ensembl') { # only want archive link on live Ensembl!
  $self->menu->add_entry( 'links', 'href' => 'http://archive.ensembl.org', 'text' => 'Archive! sites' );
    my $URL = sprintf "http://%s.archive.ensembl.org%s",
             CGI::escapeHTML($self->species_defs->ARCHIVE_VERSION),
             CGI::escapeHTML($ENV{'REQUEST_URI'});
    $self->menu->add_entry( 'links', 'href' => $URL, 'text' => 'Stable Archive! link for this page' );
  }

  else {
    $self->menu->add_entry( 'links', 'href' => "http://www.ensembl.org", 'text' => "Ensembl" );
  }
}
