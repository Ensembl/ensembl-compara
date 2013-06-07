# $Id$

package EnsEMBL::Web::Document::HTML::WhatsNew;

### This module outputs a selection of news headlines from either 
### a static HTML file or a database (ensembl_website or ensembl_production) 
### If a blog URL is configured, it will also try to pull in the RSS feed

use strict;

use Encode          qw(encode_utf8 decode_utf8);
use HTML::Entities  qw(encode_entities);

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::DBSQL::ProductionAdaptor;
use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::Document::HTML);

our $MEMD = EnsEMBL::Web::Cache->new(
  enable_compress    => 1,
  compress_threshold => 10_000,
);

sub render {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $html;

  my $release_id = $hub->param('id') || $hub->param('release_id') || $hub->species_defs->ENSEMBL_VERSION;
  return unless $release_id;

  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my $release      = $adaptor->fetch_release($release_id);
  my $release_date = $release->{'date'};
  my $html = qq{<h2 class="box-header">What's New in Release $release_id ($release_date)</h2>};

  ## Are we using static news content output from a script?
  my $file         = '/ssi/whatsnew.html';
  my $include = EnsEMBL::Web::Controller::SSI::template_INCLUDE(undef, $file);
  if ($include) {
    ## Only use static page with current release!
    if ($release_id == $hub->species_defs->ENSEMBL_VERSION && $include) {
      $html .= $include;
    }
  }
  else {
    ## Return dynamic content from the ensembl_website database
    my $news_url     = '/info/website/news.html?id='.$release_id;
    my @items = ();

    my $first_production = $hub->species_defs->get_config('MULTI', 'FIRST_PRODUCTION_RELEASE');

    if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}
        && $first_production && $release_id > $first_production) {
      ## TODO - implement way of selecting interesting news stories
      #my $p_adaptor = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);
      #if ($p_adaptor) {
      #  @items = @{$p_adaptor->fetch_changelog({'release' => $release_id, order_by => 'priority', limit => 5})};
      #}   
    }
    elsif ($hub->species_defs->multidb->{'DATABASE_WEBSITE'}{'NAME'}) { 
      @items    = @{$adaptor->fetch_news({ release => $release_id, order_by => 'priority', limit => 5 })};
    } 

    if (scalar @items > 0) {
      $html .= "<ul>\n";

      ## format news headlines
      foreach my $item (@items) {
        my @species = @{$item->{'species'}};
        my (@sp_ids, $sp_id, $sp_name, $sp_count);
      
        if (!scalar(@species) || !$species[0]) {
          $sp_name = 'all species';
        } 
        elsif (scalar(@species) > 5) {
          $sp_name = 'multiple species';
        } 
        else {
          my @names;
        
          foreach my $sp (@species) {
            if ($sp->{'common_name'} =~ /\./) {
              push @names, '<i>'.$sp->{'common_name'}.'</i>';
            } 
            else {
              push @names, $sp->{'common_name'};
            } 
          }
        
          $sp_name = join ', ', @names;
        }
      
        ## generate HTML
        $html .= qq|<li><strong><a href="$news_url#news_$item->{'id'}" style="text-decoration:none">$item->{'title'}</a></strong> ($sp_name)</li>\n|;
      }
      $html .= "</ul>\n";
    }
    else {
      $html .= "<p>No news is currently available for release $release_id.</p>\n";
    }
  }
  $html .= qq(<p><a href="/info/website/news.html">Full details of this release</a></p>);

  if ($species_defs->ENSEMBL_BLOG_URL) {
    $html .= qq(<p><a href="http://www.ensembl.info/blog/category/releases/">More release news on our blog &rarr;</a></p>);
    $html .= $self->_include_blog($hub);
  }

  return $html;
}


sub _include_blog {
  my ($self, $hub) = @_;

  my $rss_url = $hub->species_defs->ENSEMBL_BLOG_RSS;

  my $html = '<h3>Latest blog posts</h3>';

  my $blog_url  = $hub->species_defs->ENSEMBL_BLOG_URL;
  my $items = [];

  if ($MEMD && $MEMD->get('::BLOG')) {
    $items = $MEMD->get('::BLOG');
  }

  unless ($items && @$items) {
    $items = $self->get_rss_feed($hub, $rss_url, 3);

    ## encode items before caching, in case Wordpress has inserted any weird characters
    if ($items && @$items) {
      foreach (@$items) {
        while (my($k, $v) = each (%$_)) {
          $_->{$k} = encode_utf8($v);
        }
      }
      $MEMD->set('::BLOG', $items, 3600, qw(STATIC BLOG)) if $MEMD;
    }
  }

   if (scalar(@$items)) {
    $html .= "<ul>";
    foreach my $item (@$items) {
      my $title = $item->{'title'};
      my $link  = encode_entities($item->{'link'});
      my $date = $item->{'date'} ? $item->{'date'}.': ' : '';

      $html .= qq(<li>$date<a href="$link">$title</a></li>);
    }
    $html .= "</ul>";
  }
  else {
    $html .= qq(<p>Sorry, no feed is available from our blog at the moment</p>);
  }

  $html .= qq(<p><a href="$blog_url">Go to Ensembl blog &rarr;</a></p>);

  return $html;

}



1;
