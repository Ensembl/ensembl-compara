package EnsEMBL::Web::Document::Configure;

use CGI qw(escapeHTML);

use EnsEMBL::Web::Root;
our @ISA  = qw(EnsEMBL::Web::Root);

sub common_menu_items {
  my( $self, $doc ) = @_;
## Now the links on the left hand side....
  my $release = $doc->species_defs->ENSEMBL_VERSION;
  my $single_species = $ENV{'ENSEMBL_SPECIES'} && $ENV{'ENSEMBL_SPECIES'} ne 'Multi' 
      && $ENV{'ENSEMBL_SPECIES'} ne 'common' ? 1 : 0;
  my $species = $single_species ? $ENV{'ENSEMBL_SPECIES'} : 'default';
  my $species_m  = $species eq 'default' ? 'Multi'   : $species;
  my $species_d  = $species eq 'Multi'   ? 'default' : $species;
  $doc->menu->add_block( 'whattodo', 'bulleted', 'Use Ensembl to...', 'priority' => 10 );
## Check blastview is available...
  if( 1 ) {
    $doc->menu->add_entry( 'whattodo',
      'code' => 'blast',
      'href' => "/$species_m/blastview",
      'text' => 'Run a BLAST search',
    );
  }
## Check Search is available...
  if( $doc->species_defs->ENSEMBL_SEARCH ) {
    $doc->menu->add_entry( 'whattodo',
      'href'=>"/$species_d/".$doc->species_defs->ENSEMBL_SEARCH,
      'text'=>'Search Ensembl database'
    );
  }
## Check martview is available...
  if( $doc->species_defs->multiX('marts') ) {
    $doc->menu->add_entry( 'whattodo',
      'href'=>"/$species_m/martview",
      'text'=>'Data mining [BioMart]',
      'icon' => '/img/biomarticon.gif'
    );
  }
  $doc->menu->add_entry( 'whattodo',
    'href'=>"/info/data/index.html#import",
    'text'=>'Display your own data'
  );

  $doc->menu->add_entry(
    'whattodo',
    'href' => "/$species_d/exportview",
    'text' => 'Export data'
  );

  $doc->menu->add_block( 'local', 'bulleted', 'Other Links', 'priority' => 25 );
  if( $doc->species_defs->multidb && $doc->species_defs->multidb->{'ENSEMBL_WEBSITE'} ) { 
    $doc->menu->add_entry( 'local',
      'code'  => "whatsnew",
      'href' => "/$species_m/newsview?rel=$release",
      'text'  => "What's New",
      'title' => "Latest changes in Ensembl",
    );
  }
  $doc->menu->add_entry( 'local', 'href' => '/', 'text' => 'Home', 'code' => 'home' );

  my $map_link = '/sitemap.html';
  if($single_species) {
    $map_link = "/$species$map_link";
  }
  $doc->menu->add_entry( 'local', 'href' => $map_link, 'text' => 'Sitemap', 'code' => 'sitemap' );


}

sub static_menu_items {
  my( $self, $doc ) = @_;

  $doc->menu->add_block( 'docs', 'bulleted', 'Help and Documentation', 'priority' => 24 );
  $doc->menu->add_entry( 'docs',
    'href' => '/info/helpdesk',
    'text'  => 'Helpdesk',
    'title' => 'Helpdesk homepage',
    'icon' => '/img/infoicon.gif',
  );
  $doc->menu->add_entry( 'docs',
    'href' => '/info/about/',
    'text'  => 'About Ensembl',
    'title' => 'Introduction, Goals, Commitments, Citing Ensembl, Archive sites',
    'icon' => '/img/infoicon.gif',
  );
  $doc->menu->add_entry( 'docs',
    'href' => '/info/data/',
    'text'  => 'Ensembl Data',
    'title' => 'Downloads, Data import/export, Data mining, Data searching',
    'icon' => '/img/infoicon.gif',
  );
  $doc->menu->add_entry( 'docs',
    'href' => '/info/software/',
    'text'  => 'Ensembl Software',
    'title' => 'API, Installation, CVS, Versions',
    'icon' => '/img/infoicon.gif',
  );
}

sub dynamic_menu_items {

}

1;
