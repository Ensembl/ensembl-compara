package EnsEMBL::Web::Document::Configure;

use CGI qw(escapeHTML);
use strict;
use warnings;

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Object::User;

our @ISA  = qw(EnsEMBL::Web::Root);

sub common_menu_items {
  my( $self, $doc ) = @_;
## Now the links on the left hand side....

  if ($doc->species_defs->ENSEMBL_LOGINS) {
    ## Is the user logged in?
    my $user_id = $ENV{'ENSEMBL_USER_ID'};

    my $user_adaptor = EnsEMBL::Web::DBSQL::UserDB->new();

    my $flag = 'ac_mini';
    $doc->menu->add_block( $flag, 'bulleted', "Your Ensembl", 'priority' => 0 );
    my @bookmark_sections = ();

    if ($user_id) {
      #$doc->menu->add_entry( $flag, 'text' => "<a href='/common/accountview'>Your account</a> &middot; <a href='javascript:logout_link()'>Log out</a>", 'raw' => 'yes');
      #$doc->menu->add_entry( $flag, 'text' => "Bookmark this page",
      #                              'code' => 'bookmark',
      #                            'href' => "javascript:bookmark_link()" );

      my $user = EnsEMBL::Web::Object::User->new({'adaptor'=>$user_adaptor, 'id'=>$user_id});

      ## Link to existing bookmarks
      my %included = ();
      my @records = $user->bookmark_records({order_by => 'click' });
      my $found = 0;
      if ($#records > -1) { 
        $found = 1;
        my $max_bookmarks = 5;
        if ($#records < $max_bookmarks) {
          $max_bookmarks = $#records;
        }

        for my $n (0..$max_bookmarks) {
          push @bookmark_sections, &bookmark_menu_item($records[$n]);
          $included{$records[$n]->url} = "yes";
        }

      }

      foreach my $group (@{ $user->groups }) {
        $found = 1;
        my @bookmarks = $group->bookmark_records;   
        foreach my $bookmark (@bookmarks) {
          if (!$included{$bookmark->url}) {
            push @bookmark_sections, &bookmark_menu_item($bookmark);
          }
        }
      }


      if ($found) {
        push @bookmark_sections, { 'href' => 'javascript:bookmark_link()', 
                                   'text'  => 'Bookmark this page', extra_icon => '/img/bullet_toggle_plus.png' };

        push @bookmark_sections, { 'href' => '/common/accountview', 
                                   'text'  => 'More bookmarks...', extra_icon => '/img/bullet_go.png' };

      #  $doc->menu->add_entry(
      #    $flag,
      #      'href' => '/common/accountview',
      #      'text' => 'Bookmarks',
      #    'options'=> \@bookmark_sections );

      } else {
        #$doc->menu->add_entry( $flag, 'text' => "Add bookmark",
        #                              'href' => "javascript:bookmark_link()" );
      }

      #$doc->menu->add_entry( $flag, 'text' => "Your account",
      #                            'href' => "/common/accountview" );

      $doc->menu->add_entry( $flag, 'text' => "<a href='javascript:void(0);' onclick='javascript:toggle_settings_drawer();' id='settings_link'>Show account</a> &middot; <a href='javascript:void(0);' onclick='logout_link()'>Log out</a>",
                                    'raw' => "yes" );

      $doc->menu->add_entry( $flag, 'text' => "Save bookmark",
                                    'href' => "javascript:bookmark_link()" );
    
    }
    else {
      $doc->menu->add_entry( $flag, 'text' => "<a href='javascript:login_link();'>Login</a> or <a href='/common/register'>Register</a>", 'raw' => 'yes');
      $doc->menu->add_entry( $flag, 'text' => "About User Accounts",
                                  'href' => "/info/about/accounts.html",
                                  'icon' => '/img/infoicon.gif' );
    }
  }

  ## Select a random miniad if available
    if( $doc->species_defs->multidb && $doc->species_defs->multidb->{'ENSEMBL_WEBSITE'} ) {
      my $db =
      $doc->species_defs->databases ? $doc->species_defs->databases->{'ENSEMBL_WEBSITE'} : (
        $doc->species_defs->multidb ? $doc->species_defs->multidb->{'ENSEMBL_WEBSITE'} : undef
      );
      return unless $db;
      my $species = $ENV{'ENSEMBL_SPECIES'} || $ENV{'ENSEMBL_PRIMARY_SPECIES'} || 'common';
      my $miniads = $doc->species_defs->get_config($species, 'miniads');
      my $count = (ref($miniads) eq 'ARRAY') ? scalar(@$miniads) : 0;
      if ($count) {
        srand;
        my $rand = int(rand($count));
        my $miniad = $miniads->[$rand];
        my $ad_html = $doc->wrap_ad($miniad);
        $doc->menu->add_miniad($ad_html);
      }
    }


}

sub bookmark_menu_item {
  my $bookmark = shift;
  my $url = $bookmark->url;
  $url =~ s/\?/\\\?/g;
  $url =~ s/&/!and!/g;
  $url =~ s/;/!with!/g;
  my $return = { href => $url,
                 text => $bookmark->name,
                 extra_icon => '/img/bullet_star.png' };
  return $return;
}

sub static_menu_items {
  my( $self, $doc ) = @_;

  $doc->menu->add_block( 'docs', 'bulleted', 'Help & Documentation', 'priority' => 20 );

  $doc->menu->add_entry('docs', 'href'=>'/info/',         'text'=>'Table of Contents');
  $doc->menu->add_entry('docs', 'href'=>'/info/helpdesk', 'text'=>'Helpdesk');
  $doc->menu->add_entry('docs', 'href'=>'/info/about/',   'text'=>'About Ensembl');
  $doc->menu->add_entry('docs', 'href'=>'/info/data/download.html', 'text'=>'Downloading data');
  $doc->menu->add_entry('docs', 'href'=>'/info/data/index.html#import', 'text'=>'Displaying your own data');
  $doc->menu->add_entry('docs', 'href'=>'/info/software/','text'=>'Ensembl software');


}

sub dynamic_menu_items {
  my( $self, $doc ) = @_;

  ## Is the user logged in?
  my $user_id = $ENV{'ENSEMBL_USER_ID'};

  if ($user_id) {
    my $flag = 'ac_mini';
      ## to do - add a check for configurability
      my $configurable = 1;
      if ($configurable) {
        $doc->menu->add_entry_after( $flag, 'bookmark', 
                                    'text' => "Save view as...",
                                  'href' => "javascript:config_link()" );
      }
  }
}

1;
