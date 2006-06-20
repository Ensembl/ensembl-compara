package EnsEMBL::Web::Document::Configure;

use CGI qw(escapeHTML);

use EnsEMBL::Web::Root;
our @ISA  = qw(EnsEMBL::Web::Root);

sub common_menu_items {
  my( $self, $doc ) = @_;
## Now the links on the left hand side....
  my $release = $doc->species_defs->ENSEMBL_VERSION;
  my $species = $ENV{'ENSEMBL_SPECIES'} && $ENV{'ENSEMBL_SPECIES'} ne 'Multi' ? $ENV{'ENSEMBL_SPECIES'} : 'default';
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
      'text'=>'Search Ensembl'
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
    'href'=>"/$species/karyoview",
    'text'=>'Upload and view data on chromosome'
  ) unless $species eq 'default';

  $doc->menu->add_entry(
    'whattodo',
    'href' => "/$species_d/exportview",
    'text' => 'Export data'
  );
#  $doc->menu->add_entry( 'whattodo', 'href'=>"javascript:void(window.open('/perl/helpview?se=1;kw=karyoview','helpview','width=700,height=550,resizable,scrollbars'))", 'text'=>'Display your data on a karyotype diagram' );

  $doc->menu->add_block( 'docs', 'bulleted', 'Docs and downloads', 'priority' => 10 );
  $doc->menu->add_entry( 'docs',
    'href' => '/info/',
    'text'  => 'Information',
    'title' => 'Information homepage',
    'icon' => '/img/infoicon.gif',
  );

  #warn $doc->species_defs;
  #warn $doc->species_defs->databases;
  if( $doc->species_defs->multidb && $doc->species_defs->multidb->{'ENSEMBL_WEBSITE'} ) { 
    $doc->menu->add_entry( 'docs',
      'code'  => "whatsnew",
      'href' => "/$species_m/newsview?rel=$release",
      'text'  => "What's New",
      'title' => "Latest changes in Ensembl",
      'icon' => '/img/infoicon.gif',
    );
  }
  $doc->menu->add_entry( 'docs',
    'href' => '/info/about/',
    'text'  => 'About Ensembl',
    'title' => 'Introduction, Goals, Commitments, Citing Ensembl, Archive sites',
    'icon' => '/img/infoicon.gif',
  );
  $doc->menu->add_entry( 'docs',
    'href' => '/info/data/',
    'text'  => 'Ensembl data',
    'title' => 'Downloads, Data import/export, Data mining, Data searching',
    'icon' => '/img/infoicon.gif',
  );
  $doc->menu->add_entry( 'docs',
    'href' => '/info/software/',
    'text'  => 'Software',
    'title' => 'API, Installation, CVS, Versions',
    'icon' => '/img/infoicon.gif',
  );
  $doc->menu->add_block( 'links', 'bulleted', 'Other links', 'priority' => 30 );
  $doc->menu->add_entry( 'links', 'href' => '/', 'text' => 'Home' );
  my $map_link = '/sitemap.html';
  if( my $species = $ENV{'ENSEMBL_SPECIES'} ) {
    $map_link = "/$species$map_link";
  }
  $doc->menu->add_entry( 'links', 'href' => $map_link, 'text' => 'Sitemap', 'code' => 'sitemap' );

}

sub dynamic_menu_items {

}

1;
