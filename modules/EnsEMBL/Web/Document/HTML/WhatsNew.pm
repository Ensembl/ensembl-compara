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
use JSON            qw(to_json from_json);
use XML::RSS;
use HTML::TreeBuilder;

use EnsEMBL::Web::File::Utils::IO qw/file_exists read_file write_file/;
use EnsEMBL::Web::REST;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self  = shift;
  my $sd    = $self->hub->species_defs;

  return if ($SiteDefs::ENSEMBL_SKIP_RSS || !$sd->ENSEMBL_BLOG_URL);

  my $html = sprintf '<h2 class="box-header">%s %s Release %s (%s)</h2>', $sd->ENSEMBL_SITETYPE, 
                $sd->ENSEMBL_SUBTYPE, $sd->ENSEMBL_VERSION, $sd->ENSEMBL_RELEASE_DATE;

  my $release_tag = $sd->BLOG_RELEASE_TAG.$sd->ENSEMBL_VERSION;
  
  $html .= $self->_include_headlines($release_tag);

  $html .= qq(<h2 class="box-header">Other news from our blog</h2>);

  $html .= $self->_include_blog($release_tag);

  $html .= $self->show_twitter if $self->can('show_twitter');

  return $html;
}

sub _include_headlines {
  my ($self, $tag) = @_;

  my $json_path = $self->hub->species_defs->ENSEMBL_TMP_DIR.'/release.json';
  my $args      = {'no_exception' => 1};
  my $content;

  if (file_exists($json_path, $args) && -M $json_path < 1) {
    $content = from_json(read_file($json_path, $args));
  }
  else {
    ## Fetch new headlines from blog using WP REST API
    $content = $self->_get_json($tag, $json_path);
  }
  if ($content) {
    my $post_url  = $content->{'url'};
    my $headlines = $content->{'headlines'};
    my $html = '<ul>';
    foreach (@$headlines) {
      $html .= sprintf '<li>%s</li>', $_->{'title'};
    }
    $html .= sprintf '</ul><p><a href="%s">Read the full post</a> on our blog</p>', $post_url;
    return $html;   
  }
  else {
    return sprintf '<p>Could not retrieve release headlines. Please visit our <a href="%s">blog</a> for the latest news.</p>', $self->hub->species_defs->ENSEMBL_BLOG_URL;
  }
}

sub _include_blog {
  my ($self, $tag) = @_;

  my $items     = $self->read_rss_file($tag); 
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

  my $blog_url = $self->hub->species_defs->ENSEMBL_BLOG_URL;
  $html .= qq(<p style="text-align:right"><a href="$blog_url">Go to Ensembl blog</a></p>);

  return $html;
}

sub read_rss_file {
  my ($self, $tag)  = shift;
  my $hub           = $self->hub;
  my $rss_path      = $hub->species_defs->ENSEMBL_TMP_DIR.'/rss.xml';
  my $rss_url       = $hub->species_defs->ENSEMBL_BLOG_RSS;
  my $limit         = 3;

  if (!$hub || !$rss_path) {
    return [];
  }

  my $items = [];
  my $args = {'no_exception' => 1};

  if (file_exists($rss_path, $args) && -M $rss_path < 1) {
    my $content = read_file($rss_path, $args);
    if ($content) {
      $items = $self->process_xml($content, $limit, $tag);
    }
  }
  else {
    ## Fall back to fetching feed if no file cached
    $items = $self->get_rss_feed($hub, $rss_url, $rss_path, $limit, $tag);
  }
  return $items;
}

sub get_rss_feed {
  my ($self, $hub, $rss_url, $output_path, $limit,$tag) = @_;
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
    ## Write content to tmp directory in case server has no cron job to fetch it
    my $error = write_file($output_path, {'content' => $response->decoded_content, 'nice' => 1});
    $items = $self->process_xml($response->decoded_content, $limit, $tag);
  }
  else {
    warn "!!! COULD NOT GET RSS FEED from $rss_url: ".$response->code.' ('.$response->message.')';
  }
  return $items;
}

sub process_xml {
  my ($self, $content, $limit, $tag) = @_;
  my $items = [];

  eval {
    my $count = 0;
    my $rss = XML::RSS->new;
    $rss->parse($content);
    foreach my $entry (@{$rss->{'items'}}) {
      ## Skip post with release tag, as we've already show it in the main news
      my $cat = $entry->{'category'};
      my @cats = ref($cat) eq 'ARRAY' ? @$cat : ($cat);
      next if grep(/$tag/, @cats);
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
  };
  if($@) {
    warn "Error parsing blog: $@\n";
  }
  return $items;
}

sub _get_json {
  my ($self, $tag, $output_path)  = @_;
  my $sd    = $self->hub->species_defs;
  my ($rest, $response, $error, $content, $args, $token);

  if ($sd->BLOG_REST_AUTH) {
    ## Authenticate so we can get private posts, e.g. on test site
    $rest  = EnsEMBL::Web::REST->new($self->hub, $sd->BLOG_REST_AUTH); 
    $args = {
              'method' => 'post', 
              'content' => {
                            'username' => $sd->BLOG_REST_USER,
                            'password' => $sd->BLOG_REST_PASS,
                            }
              };
    ($response, $error) = $rest->fetch('token', $args);
    if ($error) {
      warn "!!! AUTHENTICATION ERROR ".$error->[0];
      return undef;
    }
    elsif (!$response->{'token'}) {
      warn "!!! AUTHENTICATION ERROR: ".$response->[0]; 
      return undef;
    }
    else {
      $token = $response->{'token'};
      #warn ">>> GOT TOKEN $token";
      $args  = {'headers' => {'Authorization' => "Bearer $token"}};
    }
  }
  
  ## Now fetch the release news using the tag
  $rest  = EnsEMBL::Web::REST->new($self->hub, $sd->BLOG_REST_URL); 

  ## Find out the ID of this tag
  #warn ">>> GETTING ID FOR TAG $tag";
  ($response, $error)  = $rest->fetch("tags?slug=$tag");
  if ($error) {
    warn "!!! REST ERROR ".$response->[0];
    return undef;
  }
  my $tag_id    = $response->[0]{'id'};
  #warn "... TAG $tag HAS ID $tag_id";
  ## Finally, fetch the actual post
  #warn ">>> FETCHING POSTS FOR THIS TAG";
  ($response, $error) = $rest->fetch("posts?tags=$tag_id", $args);
  if ($error) {
    warn "!!! REST ERROR ".$response->[0];
    return undef;
  }

  my $post = $response->[0]{'content'}{'rendered'};

  if ($post) {
    my $items = [];
    ## Parse it for H2 header tags
    my $tree = HTML::TreeBuilder->new_from_content($post);
    my @headers = $tree->find('h2');
    foreach (@headers) {
      my @children = $_->content_list;
      push @$items, {'title' => encode_utf8($children[0])};
    } 

    $content = {
                'url'       => encode_utf8($response->[0]{'link'}),
                'headlines' => $items,
                };

    ## Save the content as a JSON file
    my $error = write_file($output_path, {'content' => to_json($content), 'nice' => 1});
  }

  return $content;
}

1;
