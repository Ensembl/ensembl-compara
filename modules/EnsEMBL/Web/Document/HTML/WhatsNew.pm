# $Id$

package EnsEMBL::Web::Document::HTML::WhatsNew;

### This module outputs a selection of news headlines for the home page, 
### based on the user's settings or a default list

use strict;
use warnings;

use LWP::Simple;
use XML::RSS;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::NewsItem;
use EnsEMBL::Web::Data::Species;
use EnsEMBL::Web::Data::Release;
use EnsEMBL::Web::Document::HTML::Blog;

use base qw(EnsEMBL::Web::Root);


{

sub render {
  my $self = shift;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my $filtered = 0;
  my $html;

  my $release_id = $species_defs->ENSEMBL_VERSION;
  my $release = EnsEMBL::Web::Data::Release->new($release_id);
  if ($release) {
    my $release_date = $self->pretty_date($release->date);
    $html .= qq(<h2 class="first">What's New in Release $release_id ($release_date)</h2>);
    my $news_url = '/info/website/news/index.html';

    ## get news headlines
    my $criteria = {'release_id' => $release_id, 'news_done' => 'Y'};
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

    if (scalar(@headlines) < 5 && $filtered) {
      delete($criteria->{'species'});
      my $attr = {'limit' => 5 - @headlines, 'order_by' => ' n.priority DESC '};
      push @headlines, EnsEMBL::Web::Data::NewsItem->fetch_news_items($criteria, $attr);
    }

    if (scalar(@headlines) > 0) {

      $html .= "<ul>\n";

## format news headlines
      foreach my $item (@headlines) {

        ## sort out species names
        my @species = $item->species; 
        my (@sp_ids, $sp_id, $sp_name, $sp_count);
        if (!scalar(@species)) {
          $sp_name = 'all species';
        }
        elsif (scalar(@species) > 5) {
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
        $html .= sprintf(qq(<li><strong><a href="%s#%s" style="text-decoration:none">%s</a></strong> (%s)</li>\n),
              $news_url, $item->news_item_id, $item->title, $sp_name);

      }

      $html .= qq(</ul>
<p><a href="$news_url">More news</a>...</p>\n);
    }
    else {
      $html .= qq(<p>No news is currently available for release $release_id.</p>\n);
    }
  }
  else {
    $html .= qq(<h2 class="first">What's New in Release $release_id</h2>);
    $html .= qq(<p>No information on this release</p>);
    warn "NO RELEASE INFORMATION found in database ensembl_website!";
  }

  if ($ENSEMBL_WEB_REGISTRY->check_ajax) {
    $html .= qq(<div class="js_panel ajax" id="blog" title="['/blog.html']"><input type="hidden" class="panel_type" value="Content" /></div>);
  } else {
    my $content;
    eval {
      $self->dynamic_use('EnsEMBL::Web::Document::HTML::Blog');
      $html .=  EnsEMBL::Web::Document::HTML::Blog->render;
    };    
  }
  
  return $html;
}

}

1;
