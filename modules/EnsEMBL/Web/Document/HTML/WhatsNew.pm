package EnsEMBL::Web::Document::HTML::WhatsNew;

### This module outputs two alternative tabbed panels for the Ensembl homepage
### 1) the "About Ensembl" blurb
### 2) A selection of news headlines, based on the user's settings or a default list

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::DBSQL::NewsAdaptor;

{

sub render {

### Renders the HTML for two tabbed panels - blurb and news headlines

## JS tab-switching, plus Ensembl blurb
  my $html = qq(

<div class="pale boxed">
<div class="species-news">
);

## News headlines

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $release_id = $species_defs->ENSEMBL_VERSION;

  my $user_id = $ENV{'ENSEMBL_USER_ID'};
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;

  my $DB = $species_defs->databases->{'ENSEMBL_WEBSITE'};
  my $adaptor = EnsEMBL::Web::DBSQL::NewsAdaptor->new( $DB );
  my @headlines;
  my $filtered = 0;

  ## get news headlines
  my $criteria = {'release'=>$release_id};
  if ($user_id && $user_id > 0) {
    $criteria->{'species'} = [];
    ## check for user filters
    my @filters = $user->news_records;
    ## Look up species names for use in query
    foreach my $f (@filters) {
      if ($f->species && $f->species ne 'none') {
        $filtered = 1;
        $criteria->{'species'} = $f->species;
      }
    }
  }

  @headlines = @{$adaptor->fetch_headlines($criteria, '', '5')};

  my %current_spp = %{$adaptor->fetch_species($release_id)};

  if (scalar(@headlines) > 0) {
    
    my @releases = @{$adaptor->fetch_releases({'release'=>$release_id})};
    my $release_details = $releases[0];
    my $release_date = $release_details->{'long_date'};
  
    $html .= '<h3>';
    $html .= 'Your ' if $filtered;
    $html .= qq(Ensembl headlines: <span class="text">Release $release_id ($release_date)</span></h3><br />);

    ## format news headlines
    foreach my $item (@headlines) {

      ## sort out species names
      my $species = $item->{'species'};
      my (@sp_ids, $sp_id, $sp_dir, $sp_name, $sp_count);
      if (ref($species)) {
        $sp_id = ${$species}[0];
        @sp_ids = @{$species};
      }
      else {
        $sp_id = $species;
        @sp_ids = ($sp_id);
      }
      if ($sp_id) {
        $sp_dir = $current_spp{$sp_id};
        $sp_count = scalar(@sp_ids);
        if ($sp_count > 1) {
          for (my $j=0; $j<$sp_count; $j++) {
            $sp_name .= ', ' unless $j == 0;
            my @name_bits = split('_', $current_spp{$sp_ids[$j]});
            $sp_name .= '<i>'.substr($name_bits[0], 0, 1).'. '.$name_bits[1].'</i>';
          }
        }
        else {
          ($sp_name = $sp_dir) =~ s/_/ /g;
          $sp_name = "<i>$sp_name</i>";
        }
      }
      else {
        $sp_dir = 'Multi';
        $sp_name = 'all species';
      } 
 
      ## generate HTML
      $html .= '<p>';
      if (defined $sp_count && $sp_count == 1) {
        $html .= qq(<a href="/$sp_dir/"><img src="/img/species/thumb_$sp_dir.png" alt="" title="Go to the $sp_name home page" class="sp-thumb" style="height:30px;width:30px;border:1px solid #999" /></a>);
      }
      else {
        $html .= qq(<img src="/img/ebang-30x30.png" alt="" class="sp-thumb" style="height:30px;width:30px;border:1px solid #999" />);
      }

      $html .= sprintf(qq(<strong><a href="/%s/newsview?rel=%s#cat%s" style="text-decoration:none">%s</a></strong> (%s)</p>),
              $sp_dir, $release_id, $item->{'news_cat_id'}, $item->{'title'}, $sp_name);

    }

    $html .= qq(<p><a href="/Multi/newsview?rel=current">More news</a>...</p>\n</div>\n);
  }
  else {
    if ($filtered) {
      $html .= qq(<p>No news could be found for your selected species/topics.</p>
<p><a href="/Multi/newsview?rel=current">Other news</a>...</p>\n</div>\n);
    }
    else {
      $html .= qq(<p>No news is currently available for release $release_id.</p>\n</div>\n);
    }
  }

  if ($species_defs->ENSEMBL_LOGINS) {
    if ($user_id && $user_id > 0) {
      if (!$filtered) {
        $html .= qq(Go to <a href="/common/accountview?tab=news">your account</a> to customise this news panel);
      }
    }
    else {
      $html .= qq(<a href="javascript:login_link();">Log in</a> to see customised news &middot; <a href="/common/register">Register</a>);
    }
  }

  $html .= qq(
</div>
);

  return $html;
}

}

1;
