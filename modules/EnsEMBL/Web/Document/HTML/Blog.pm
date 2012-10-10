package EnsEMBL::Web::Document::HTML::Blog;

### This module outputs a selection of blog headlines for the home page, 

use strict;
use warnings;

use Encode qw(encode_utf8);

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
      my $link  = $item->{'link'};
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
