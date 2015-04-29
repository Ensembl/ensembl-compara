=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Document::HTML::WhatsNew;

### This module outputs a selection of news headlines from  
### the ensembl_production database
### If a blog URL is configured, it will also try to pull in the RSS feed

use strict;

use Encode          qw(encode_utf8 decode_utf8);
use HTML::Entities  qw(encode_entities);

use EnsEMBL::Web::DBSQL::ArchiveAdaptor;
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

  my ($headlines, @links, $blog);
  if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}) {
    ($headlines, @links) = $self->show_headlines;
  }

  $html .= $headlines if $headlines;

  if ($species_defs->ENSEMBL_BLOG_URL) {
    push @links, qq(<a href="http://www.ensembl.info/blog/category/releases/">More news on our blog</a></p>);
    $blog = $self->_include_blog($hub);
  }
  if (scalar(@links)) {
    $html .= sprintf('<p>%s</p>', join(' | ', @links));
  }
  $html .= $blog if $blog;

  return if ($species_defs->ENSEMBL_SITETYPE eq 'Archive');
  
  $html .= $self->show_twitter();

  return $html;
}

sub show_twitter {
  my $self          = shift;
  my $species_defs  = $self->hub->species_defs;
  my $twitter_html  = '';

  my $twitter_user = $species_defs->ENSEMBL_TWITTER_ACCOUNT;
  my $widget_id    = $species_defs->TWITTER_FEED_WIDGET_ID;
  if ($twitter_user && $widget_id) {
    $twitter_html = sprintf(qq(<a class="twitter-timeline" href="https://twitter.com/%s" height="400" data-widget-id="%s">Recent tweets from @%s</a>
<script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+"://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);}}(document,"script","twitter-wjs");</script>),
                $twitter_user, $widget_id, $twitter_user);
  }

  return $twitter_html;
}

sub show_headlines {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my ($headlines, @links);

  my $release_id = $hub->species_defs->ENSEMBL_VERSION;

  my $header_text = $self->news_header($hub, $release_id);
  my $headlines   = qq{<h2 class="box-header"><img src="/i/24/announcement.png" style="vertical-align:middle" /> What's New in $header_text</h2>};

  my $first_production = $hub->species_defs->get_config('MULTI', 'FIRST_PRODUCTION_RELEASE');

  if ($first_production) {
    if ($release_id >= $first_production) {

      my $news_url     = '/info/website/news.html?id='.$release_id;
      my @items = ();

      my $adaptor = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);
      if ($adaptor) {
        @items = @{$adaptor->fetch_headlines({'release' => $release_id, limit => 3})};
      }   

      if (scalar @items > 0) {
        $headlines .= "<ul>\n";

        ## format news headlines
        foreach my $item (@items) {
          $headlines .= qq|<li><strong><a href="$news_url#change_$item->{'id'}" style="text-decoration:none">$item->{'title'}</a></strong></li>\n|;
        }
        $headlines .= "</ul>\n";
        push @links, qq(<p style="text-align:right"><a href="/info/website/news.html">Full details</a>);

      }
      else {
        $headlines .= "<p>No news is currently available for release $release_id.</p>\n";
      }
    }

    if ($release_id > $first_production) {
      push @links, qq(<a href="/info/website/news_by_topic.html?topic=web">All web updates, by release</a>);
    }
  }
  else {
    $headlines .= "<p>No news is currently available for release $release_id.</p>\n";
  }
  return ($headlines, @links);
}

sub _include_blog {
  my ($self, $hub) = @_;

  my $rss_url = $hub->species_defs->ENSEMBL_BLOG_RSS;

  my $html = '<h3><img src="/i/wordpress.png"> Latest blog posts</h3>';

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

  $html .= qq(<p style="text-align:right"><a href="$blog_url">Go to Ensembl blog &rarr;</a></p>);

  return $html;

}

1;
