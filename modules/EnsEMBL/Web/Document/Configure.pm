package EnsEMBL::Web::Document::Configure;

use CGI qw(escapeHTML);
use strict;
use warnings;

use EnsEMBL::Web::Root;
use EnsEMBL::Web::RegObj;

our @ISA  = qw(EnsEMBL::Web::Root);

sub common_menu_items {
  my( $self, $doc ) = @_;
## Now the links on the left hand side....

  if ($doc->species_defs->ENSEMBL_LOGINS) {
    ## Is the user logged in?
    my $user_id = $ENV{'ENSEMBL_USER_ID'};

    my $flag = 'ac_mini';
    $doc->menu->add_block( $flag, 'bulleted', "Your $SiteDefs::ENSEMBL_SITETYPE", 'priority' => 0 );
    my @bookmark_sections = ();

    if ($user_id) {
      #$doc->menu->add_entry( $flag, 'text' => "<a href='/common/user/account'>Your account</a> &middot; <a href='javascript:logout_link()'>Log out</a>", 'raw' => 'yes');
      #$doc->menu->add_entry( $flag, 'text' => "Bookmark this page",
      #                              'code' => 'bookmark',
      #                            'href' => "javascript:bookmark_link()" );

      my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;

      ## Link to existing bookmarks
      my %included = ();
      my @records = @{ $user->bookmarks({order_by => 'click' }) };
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
        my @bookmarks = @{ $group->bookmarks };   
        foreach my $bookmark (@bookmarks) {
          if (!$included{$bookmark->url}) {
            push @bookmark_sections, &bookmark_menu_item($bookmark);
          }
        }
      }


      if ($found) {
        push @bookmark_sections, { 'href' => 'javascript:bookmark_link()', 
                                   'text'  => 'Bookmark this page', extra_icon => '/img/bullet_toggle_plus.png' };

        push @bookmark_sections, { 'href' => '/common/user/account', 
                                   'text'  => 'More bookmarks...', extra_icon => '/img/bullet_go.png' };

      #  $doc->menu->add_entry(
      #    $flag,
      #      'href' => '/common/user/account',
      #      'text' => 'Bookmarks',
      #    'options'=> \@bookmark_sections );

      } else {
        #$doc->menu->add_entry( $flag, 'text' => "Add bookmark",
        #                              'href' => "javascript:bookmark_link()" );
      }

      $doc->menu->add_entry( $flag, 'text' => "<a href='#' onclick='javascript:toggle_settings_drawer();' id='settings_link'>Show account</a> &middot; <a href='#' onclick='logout_link()'>Log out</a>",
                                    'raw' => "yes" );

      $doc->menu->add_entry( $flag, 'text' => "Bookmark this page",
                                    'href' => "javascript:bookmark_link()" );
    
      #$doc->menu->add_entry( $flag, 'text' => "Your account",
      #                            'href' => "/common/user/account" );

    }
    else {
      $doc->menu->add_entry( $flag, 'text' => "<a href='javascript:login_link();'>Login</a> or <a href='/common/user/register'>Register</a>", 'raw' => 'yes');
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
  $doc->menu->add_block( 'docs', 'nested', 'Help & Documentation', 'priority' => 20 );
  my $URI = $doc->{_renderer}->{r}->uri;

  my $tree = $doc->species_defs->ENSEMBL_WEB_TREE->{info};
  my @dirs  = grep { $_ !~ /(:?\.html|^_)/ } keys %$tree;

  foreach my $dir (@dirs) {
    my $node = $tree->{$dir};
    my $options = [];
    my $link = $node->{_path};
    my $text = $node->{_title};
    next unless $text;
    next if $link =~ /genomes/;
    next unless ($link);

    ## Second-level nav for current section
    if ($URI =~ m#^/info# && index($URI, $link) > -1) {
      my @subdirs = grep { $_ !~ /(:?\.html|^_)/ } keys %$node;
      my @pages = grep { /\.html/ } keys %$node;
      my ($url, $title);

      foreach my $subdir (@subdirs) {
        $url   = $node->{$subdir}->{_path};
        $title = $node->{$subdir}->{_title};
        push @$options, {'href'=>$url, 'text'=>$title} if $title;
      }
      foreach my $page (sort { $node->{$a} cmp $node->{$b} } @pages) {
        $url   = $node->{_path} . $page;
        $title = $node->{$page}->{_title};
        push @$options, {'href'=>$url, 'text'=>$title} if $title;
      }
    }
    $doc->menu->add_entry('docs', 'href'=> $link, 'text'=> $text, 'options' => $options );
  }
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
#        $doc->menu->add_entry_after( $flag, 'bookmark', 
#                                    'text' => "Save DAS sources...",
#                                  'href' => "javascript:das_link()" );
        $doc->menu->add_entry_after( $flag, 'bookmark', 
                                    'text' => "Save configuration as...",
                                  'href' => "javascript:add_config()" );
      }
  }
}

1;
