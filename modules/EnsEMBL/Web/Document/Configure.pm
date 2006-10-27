package EnsEMBL::Web::Document::Configure;

use CGI qw(escapeHTML);

use EnsEMBL::Web::Root;
our @ISA  = qw(EnsEMBL::Web::Root);

sub common_menu_items {
  my( $self, $doc ) = @_;
## Now the links on the left hand side....
  warn "DOCUMENT: " . $doc->{'_object'};
  if ($doc->species_defs->ENSEMBL_LOGINS) {
    ## Is the user logged in?
    my $user_id = $ENV{'ENSEMBL_USER_ID'};

    my $user_adaptor = EnsEMBL::Web::DBSQL::UserDB->new();

    my $flag = 'ac_mini';
    $doc->menu->add_block( $flag, 'bulleted', "Your Ensembl", 'priority' => 0 );

    if ($user_id) {

      my $user = $user_adaptor->find_user_by_user_id($user_id);
      $doc->menu->add_entry( $flag, 'text' => $user->name . qq( &middot; <a href="javascript:logout_link()">log out</a>),
                                  'icon' => '/img/infoicon.gif',
                                  'raw'  => 1);

      my @records = $user->bookmark_records({order_by => 'click' }); 
      my @bookmark_sections = ();
      my $max_bookmarks = 5;
      if ($#records < $max_bookmarks) {
        $max_bookmarks = $#records;
      }
      for my $n (0..$max_bookmarks) {
        my $url = $records[$n]->url;
        $url =~ s/\?/\\\?/g;
        $url =~ s/&/!and!/g;
        $url =~ s/;/!with!/g;
        push @bookmark_sections, { href => "/common/redirect?url=" . $url . "&id=" . $records[$n]->id, 
                                   text => $records[$n]->name }; 
      }

      push @bookmark_sections, { 'href' => '/common/update_account?node=accountview', 
                                 'text'  => 'More bookmarks...' };
      push @bookmark_sections, { 'href' => 'javascript:bookmark_link()', 
                                 'text'  => 'Bookmark this page' };

      $doc->menu->add_entry(
        $flag,
        'href'=>'/common/update_account?node=accountview',
        'text'=>'Bookmarks',
        'options'=>\@bookmark_sections,       );

     #$doc->menu->add_entry(
     #           $flag,
     #           'href' => 'javascript:bookmark_link()',
     #           'text' => 'Add bookmark'
     #           );

      $doc->menu->add_entry( $flag, 'text' => "Your account",
                                  'href' => "/common/update_account?node=accountview" );
    }
    else {
      $doc->menu->add_entry( $flag, 'text' => "Login/Register",
                                  'href' => "javascript:login_link()" );
      $doc->menu->add_entry( $flag, 'text' => "About User Accounts",
                                  'href' => "/info/about/accounts.html",
                                  'icon' => '/img/infoicon.gif' );
    }
  }

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

  my @info_sections = (
    {'href' => '/info/',          'text'  => 'Table of Contents'},
    {'href' => '/info/helpdesk',  'text'  => 'Helpdesk'},
    {'href' => '/info/about/',    'text'  => 'About Ensembl'},
    {'href' => '/info/data/',     'text'  => 'Ensembl Data'},
    {'href' => '/info/software/', 'text'  => 'Ensembl Software'},
  );

  $doc->menu->add_entry(
        'local',
        'href'=>'/info/',
        'text'=>'Help & Documentation',
        'options'=>\@info_sections,
      );


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

=pod
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
=cut
}

sub dynamic_menu_items {

}

1;
