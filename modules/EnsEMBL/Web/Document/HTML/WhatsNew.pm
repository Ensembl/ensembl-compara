=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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
use EnsEMBL::Web::File::Utils::IO qw/file_exists read_file write_file/;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $html;

  return if $SiteDefs::ENSEMBL_SKIP_RSS;

  my ($headlines, @links, $blog);
  if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}) {
    ($headlines, @links) = $self->show_headlines;
  }

  $html .= $headlines if $headlines;

  if ($species_defs->ENSEMBL_BLOG_URL) {
    push @links, qq(<a href="//www.ensembl.info/blog/category/releases/">More news on our blog</a></p>);
    $blog = $self->_include_blog($hub);
  }
  if (scalar(@links)) {
    $html .= sprintf('<p>%s</p>', join(' | ', @links));
  }
  $html .= $blog if $blog;

  return $html if ($species_defs->ENSEMBL_SUBTYPE eq 'Archive');
  
  #$html .= $self->show_twitter();

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

  return qq(<div class="homepage-twitter">$twitter_html</div>);
}

sub show_headlines {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my ($headlines, @links);

  my $release_id = $hub->species_defs->ENSEMBL_VERSION;

  my $header_text = $self->news_header($hub, $release_id);
  my $headlines   = qq{<h2 class="box-header">$header_text</h2>};

  my $first_production = $hub->species_defs->get_config('MULTI', 'FIRST_PRODUCTION_RELEASE');

  if ($first_production) {
    if ($release_id >= $first_production) {

      my $news_url     = '/info/website/news.html?id='.$release_id;
      my @items = ();

      my $adaptor = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);
      if ($adaptor) {
        @items = @{$adaptor->fetch_headlines({'release' => $release_id, limit => 5})};
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

  my $rss_path  = $hub->species_defs->ENSEMBL_TMP_DIR.'/rss.xml';
  my $rss_url   = $hub->species_defs->ENSEMBL_BLOG_RSS;
  my $items     = $self->read_rss_file($hub, $rss_path, $rss_url, 3); 
  my $html;

  if (scalar(@{$items||[]})) {
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

  my $blog_url = $hub->species_defs->ENSEMBL_BLOG_URL;
  $html .= qq(<p style="text-align:right"><a href="$blog_url">Go to Ensembl blog</a></p>);

  return $html;
}

sub read_rss_file {
  my ($self, $hub, $rss_path, $rss_url, $limit) = @_;
  if (!$hub || !$rss_path) {
    return [];
  }

  my $items = [];
  my $args = {'no_exception' => 1};

  if (file_exists($rss_path, $args) && -M $rss_path < 1) {
    my $content = read_file($rss_path, $args);
    if ($content) {
      ## Does this feed work best with XML::Atom or XML:RSS? 
      my $rss_type = $rss_path =~ /atom/ ? 'atom' : 'rss';
      $items = $self->process_xml($rss_type, $content, $limit);
    }
  }
  else {
    ## Fall back to fetching feed if no file cached
    $items = $self->get_rss_feed($hub, $rss_url, $rss_path, $limit);
  }
  return $items;
}

sub get_rss_feed {
  my ($self, $hub, $rss_url, $output_path, $limit) = @_;
  if (!$hub || !$rss_url) {
    return [];
  }

  my $ua = LWP::UserAgent->new;
  my $proxy = $hub->web_proxy;
  $ua->proxy( 'http', $proxy ) if $proxy;
  #$ua->timeout(5);

  my $items = [];

  my $response = $ua->get($rss_url);
  if ($response->is_success) {
    ## Does this feed work best with XML::Atom or XML:RSS? 
    my $rss_type = $rss_url =~ /atom/ ? 'atom' : 'rss';
    ## Write content to tmp directory in case server has no cron job to fetch it
    my $error = write_file($output_path, {'content' => $response->decoded_content, 'nice' => 1});
    $items = $self->process_xml($rss_type, $response->decoded_content, $limit);
  }
  else {
    warn "!!! COULD NOT GET RSS FEED from $rss_url: ".$response->code.' ('.$response->message.')';
  }
  return $items;
}

sub process_xml {
  my ($self, $rss_type, $content, $limit) = @_;
  my $items = [];

  eval {
    my $count = 0;
    if ($rss_type eq 'atom') {
      die 'Cannot use XML::Atom::Feed' unless $self->dynamic_use('XML::Atom::Feed');
      my $feed = XML::Atom::Feed->new(\$content);
      my @entries = $feed->entries;
      foreach my $entry (@entries) {
        my ($link) = grep { $_->rel eq 'alternate' } $entry->link;
        my $date  = $self->pretty_date(substr($entry->published, 0, 10), 'daymon');
        my $item = {
                'title'   => encode_utf8($entry->title),
                'content' => encode_utf8($entry->content),
                'link'    => encode_utf8($link->href),
                'date'    => encode_utf8($date),
        };
        push @$items, $item;
        $count++;
        last if ($limit && $count == $limit);
      }
    }
    elsif ($rss_type eq 'rss') {
      die 'Cannot use XML::RSS' unless $self->dynamic_use('XML::RSS');
      my $rss = XML::RSS->new;
      $rss->parse($content);
      foreach my $entry (@{$rss->{'items'}}) {
        my $date = substr($entry->{'pubDate'}, 5, 11);
        my $item = {
            'title'   => encode_utf8($entry->{'title'}),
            'content' => encode_utf8($entry->{'http://purl.org/rss/1.0/modules/content/'}{'encoded'}),
            'link'    => encode_utf8($entry->{'link'}),
            'date'    => encode_utf8($date),
        };
        push @$items, $item;
        $count++;
        last if ($limit && $count == $limit);
      }
    }
  };
  if($@) {
    warn "Error parsing blog: $@\n";
  }
  return $items;
}

1;
