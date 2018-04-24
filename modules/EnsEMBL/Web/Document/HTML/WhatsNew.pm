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

### This module uses our blog's RSS feed to create a list of headlines
### Note that the RSS XML is cached to avoid saturating our blog's bandwidth! 

use strict;

use Encode          qw(encode_utf8 decode_utf8);
use HTML::Entities  qw(encode_entities);

use EnsEMBL::Web::DBSQL::ArchiveAdaptor;
use EnsEMBL::Web::File::Utils::IO qw/file_exists read_file write_file/;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self  = shift;
  my $sd    = $self->hub->species_defs;

  return if ($SiteDefs::ENSEMBL_SKIP_RSS || !$sd->ENSEMBL_BLOG_URL);

  my $html = sprintf '<h2 class="box-header">%s %s Release %s (%s)</h2>', $sd->ENSEMBL_SITETYPE, 
                $sd->ENSEMBL_SUBTYPE, $sd->ENSEMBL_VERSION, $sd->ENSEMBL_RELEASE_DATE;

  $html .= $self->_include_blog($self->hub, $sd->ENSEMBL_VERSION);

  $html .= qq(<h2 class="box-header">Other news from our blog</h2>);

  $html .= $self->_include_blog($self->hub);

  $html .= $self->show_twitter if $self->can('show_twitter');

  return $html;
}

sub _include_blog {
  my ($self, $hub, $version) = @_;
  my ($rss_path, $rss_url, $limit);

  if ($version) {
    return '<p>Release headlines go here</p>';
  }
  else {
    $rss_path  = $hub->species_defs->ENSEMBL_TMP_DIR.'/rss.xml';
    $rss_url   = $hub->species_defs->ENSEMBL_BLOG_RSS;
    $limit     = 3;
  }

  my $items     = $self->read_rss_file($hub, $rss_path, $rss_url, $limit); 
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
