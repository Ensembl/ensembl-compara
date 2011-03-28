package EnsEMBL::Web::Document::HTML::Blog;

### This module outputs a selection of blog headlines for the home page, 

use strict;
use warnings;

use LWP::UserAgent;

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::Document::HTML);

our $MEMD = EnsEMBL::Web::Cache->new(
  enable_compress    => 1,
  compress_threshold => 10_000,
);

sub render {
  my $self  = shift;
  my $hub = new EnsEMBL::Web::Hub;

  my $blog_url = $hub->species_defs->ENSEMBL_BLOG_URL;
  my $blog_rss = $hub->species_defs->ENSEMBL_BLOG_RSS;
  ## Does this feed work best with XML::Atom or XML:RSS? 
  my $rss_type = $blog_rss =~ /atom/ ? 'atom' : 'rss';

  my $html = '<h3>Latest blog posts</h3>';
   
  if ($hub->cookies->{'ENSEMBL_AJAX'}) {
    $html .= qq(<div class="js_panel ajax" id="blog"><input type="hidden" class="ajax_load" value="/blog.html" /><inpu
t type="hidden" class="panel_type" value="Content" /></div>);
  } 
  else {
    my $img_url = $hub->species_defs->img_url;

    my $blog = $MEMD && $MEMD->get('::BLOG') || '';
  
    unless ($blog) {
      my @items;
      my $ua = new LWP::UserAgent;
      my $proxy = $hub->species_defs->ENSEMBL_WWW_PROXY;
      $ua->proxy( 'http', $proxy ) if $proxy;
      $ua->timeout(5);

      my $response = $ua->get($blog_rss);
      
      if ($response->is_success) {
        my $count = 0;
        if ($rss_type eq 'atom' && $self->dynamic_use('XML::Atom::Feed')) {
          my $feed = XML::Atom::Feed->new(\$response->decoded_content);
          my @entries = $feed->entries;
          foreach my $entry (@entries) {
            my ($link) = grep { $_->rel eq 'alternate' } $entry->link;
            my $date  = $self->pretty_date(substr($entry->published, 0, 10), 'daymon');
            my $item = {
              'title' => $entry->title,
              'link'  => $link->href,
              'date'  => $date,
              };
            push @items, $item;
            $count++;
            last if $count == 3;
          }
        }
        elsif ($rss_type eq 'rss' && $self->dynamic_use('XML::RSS')) {
          my $rss = XML::RSS->new;
          $rss->parse($response->decoded_content);
          foreach my $entry (@{$rss->{'items'}}) {
            my $date = substr($entry->{'pubDate'}, 5, 11);
            my $item = {
              'title' => $entry->{'title'},
              'link'  => $entry->{'link'},,
              'date'  => $date,
              };
            push @items, $item;
            $count++;
            last if $count == 3;
          }
        }
        else {
          warn "!!! UNKNOWN RSS METHOD DEFINED";
        } 
      }
      if (@items) {
        $blog .= "<ul>";
        foreach my $item (@items) {
          my $title = $item->{'title'};
          my $link  = $item->{'link'};
          my $date = $item->{'date'} ? $item->{'date'}.': ' : '';
  
          $blog .= qq(<li>$date<a href="$link">$title</a></li>); 
        }
        $blog .= "</ul>";
      } 
      else {
        $blog .= qq(<p>Sorry, no feed is available from our blog at the moment</p>);
      }
  
      $blog .= qq(<a href="$blog_url">Go to Ensembl blog &rarr;</a>);

      $MEMD->set('::BLOG', $blog, 3600, qw(STATIC BLOG))
      if $MEMD;
    }

    $html .= $blog;
  }
  return $html;
}

1;
