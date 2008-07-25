package EnsEMBL::Web::Document::HTML::WhatsNew;

### This module outputs two alternative tabbed panels for the Ensembl homepage
### 1) the "About Ensembl" blurb
### 2) A selection of news headlines, based on the user's settings or a default list

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::NewsItem;
use EnsEMBL::Web::Data::Species;
use EnsEMBL::Web::Data::Release;
use EnsEMBL::Web::Data::MiniAd;
use LWP::Simple;
#use XML::RSS;

use base qw(EnsEMBL::Web::Root);


{

sub render {
  my $self = shift;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my $filtered = 0;

  my $release_id = $species_defs->ENSEMBL_VERSION;
  my $release = EnsEMBL::Web::Data::Release->new($release_id);
  my $release_date = $self->pretty_date($release->date);

  my $news_url = '/info/website/news/index.html';

  my $html = qq(<div class="species-news">
<h2>What's New in Release $release_id ($release_date)</h2>);

  ## get a random miniad
  my $miniad = EnsEMBL::Web::Data::MiniAd->fetch_random;

  if ($miniad) {
    $html .=  sprintf('<a href="%s"><img class="float-right" style="width:150px;height:200px" src="/img/mini-ads/%s" alt="%s" title="%s" /></a>', $miniad->url, $miniad->image, $miniad->alt, $miniad->alt);
  }

  ## get news headlines
  my $criteria = {'release_id' => $release_id};
  if ($user && $user->id) {
    $criteria->{'species'} = [];
    ## check for user filters
    my @filters = $user->newsfilters;
    ## Look up species names for use in query
    foreach my $f (@filters) {
      if ($f->species && $f->species ne 'none') {
        $filtered = 1;
        $criteria->{'species'} = $f->species;
      }
    }
  }
  my $attr = {'limit' => 5, 'order_by' => ' n.priority DESC '};

  my @headlines = EnsEMBL::Web::Data::NewsItem->fetch_news_items($criteria, $attr);

  my %species_lookup; 
  my @all_species = EnsEMBL::Web::Data::Species->find_all;
  foreach my $sp (@all_species) {
    $species_lookup{$sp->species_id} = $sp->name;
  }

  if (scalar(@headlines) > 0) {

    $html .= "<ul>\n";

## format news headlines
    foreach my $item (@headlines) {

      ## sort out species names
      my @species = $item->species; 
      my (@sp_ids, $sp_id, $sp_name, $sp_count);
      my $news_url = '';
      if ($#species == $#all_species) {
        $sp_name = 'all species';
      }
      elsif ($#species > 5) {
        $sp_name = 'multiple species';
      }
      else {
        my @names;
        foreach my $sp (@species) {
          if ($sp->common_name =~ /\./) {
            push @names, '<i>'.$sp->common_name.'</i>';
          }
          else {
            push @names, $sp->common_name;
          } 
        }
        $sp_name = join(', ', @names);
      }
## generate HTML
      $html .= sprintf(qq(<li><strong><a href="%s#%s" style="text-decoration:none">%s</a></strong> (%s)</p>\n),
              $news_url, $item->news_item_id, $item->title, $sp_name);

    }

    $html .= qq(</ul>
<p><a href="$news_url">More news</a>...</p>\n);
  }
  else {
    if ($filtered) {
      $html .= qq(<p>No news could be found for your selected species/topics.</p>
<p><a href="$news_url">Other news</a>...</p>\n);
    }
    else {
      $html .= qq(<p>No news is currently available for release $release_id.</p>\n);
    }
  }
  $html .= '</div>';


  ## Ensembl blog (ensembl.blogspot.com)
  $html .= qq(<h2>Latest Blog Entries</h2>
      <ul>
        <li>New Release notes and BAC clones in mouse</li>
        <li>Ensembl US East Coast Tour</li>
        <li>March workshops, release and down time</li>
        <p><a href="http://ensembl.blogspot.com/">Go to Ensembl blog &rarr;</a></p>
      </ul>);

=pod
  if ($species_defs->ENSEMBL_LOGINS) {
    if ($user && $user->id) {
      #if (!$filtered) {
        $html .= qq(<p>Go to <a href="/common/user/account?tab=news">your account</a> to customise this news panel</p>);
      #}
    }
    else {
      $html .= qq(<p><a href="javascript:login_link();">Log in</a> to see customised news &middot; <a href="/common/user/register">Register</a></p>);
    }
  }
=cut
  return $html;
}

}

1;
