# $Id$

package EnsEMBL::Web::Document::HTML::WhatsNew;

### This module outputs a selection of news headlines for the home page, 
### based on the user's settings or a default list

use strict;

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::Document::HTML::Blog;
use EnsEMBL::Web::Hub;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self         = shift;
  my $hub          = new EnsEMBL::Web::Hub;
  my $species_defs = $hub->species_defs;
  my $file         = '/ssi/whatsnew.html';
  my $fpath        = $species_defs->ENSEMBL_SERVERROOT . $file;
  
  return EnsEMBL::Web::Controller::SSI::template_INCLUDE(undef, $file) if -e $fpath;

  my $release_id = $hub->species_defs->ENSEMBL_VERSION;
  
  return unless $release_id;

  my $adaptor = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub);
  
  return unless $adaptor;

  my $release      = $adaptor->fetch_release($release_id);
  my $release_date = $self->pretty_date($release->{'date'});
  my $html         = qq{<h2 class="first">What's New in Release $release_id ($release_date)</h2>};
  my $news_url     = '/info/website/news/index.html';
  my @headlines    = @{$adaptor->fetch_news({ release => $release_id, limit => 5 })};
  my ($news, $changelog);
  
  if (scalar @headlines > 0) {
    $html .= "<ul>\n";

    ## format news headlines
    foreach my $item (@headlines) {
      my @species = @{$item->{'species'}};
      my (@sp_ids, $sp_id, $sp_name, $sp_count);
      
      if (!scalar(@species) || !$species[0]) {
        $sp_name = 'all species';
      } elsif (scalar(@species) > 5) {
        $sp_name = 'multiple species';
      } else {
        my @names;
        
        foreach my $sp (@species) {
          if ($sp->{'common_name'} =~ /\./) {
            push @names, '<i>'.$sp->{'common_name'}.'</i>';
          } else {
            push @names, $sp->{'common_name'};
          } 
        }
        
        $sp_name = join ', ', @names;
      }
      
      ## generate HTML
      $html .= qq{<li><strong><a href="$news_url#news_$item->{'id'}" style="text-decoration:none">$item->{'title'}</a></strong> ($sp_name)</li>\n};
    }

    $html .= "</ul>\n";
    $news = 1;
  }

  if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}) {
    $changelog = 1;
    $html .= qq{<ul><li><strong><a href="/info/website/news/changelog.html" style="text-decoration:none">Details of data updates, API changes, etc</a></strong></li></ul>};
  }

  if ($news) {
    $html .= qq{<p><a href="$news_url">More news</a>...</p>\n};
  } elsif (!$news && !$changelog) {
    $html .= "<p>No news is currently available for release $release_id.</p>\n";
  }

  if ($hub->species_defs->ENSEMBL_BLOG_URL) {
    $html .= '<h3>Latest blog posts</h3>';
    
    if ($hub->cookies->{'ENSEMBL_AJAX'}) {
      $html .= qq(<div class="js_panel ajax" id="blog"><input type="hidden" class="ajax_load" value="/blog.html" /><input type="hidden" class="panel_type" value="Content" /></div>);
    } else {
      $html .= EnsEMBL::Web::Document::HTML::Blog::render;
    }    
  }
  
  return $html;
}

1;
