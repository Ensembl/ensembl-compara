package EnsEMBL::Web::Document::HTML::Blog;

### This module outputs a selection of news headlines for the home page, 
### based on the user's settings or a default list

use strict;
use warnings;

use LWP::UserAgent qw();
use XML::RSS qw();
use Data::Dumper;

use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::Root);

our $MEMD = EnsEMBL::Web::Cache->new(
  enable_compress    => 1,
  compress_threshold => 10_000,
);


{

sub render {
  my $self = shift;

  ## Ensembl blog (ensembl.blogspot.com)
  my $html = qq(<h2>Latest Blog Entries</h2>);

  my $items = $MEMD ? $MEMD->get('::BLOG') : undef;

  unless ($items) {
    my $ua = new LWP::UserAgent;
    $ua->proxy(['http', 'ftp'], 'http://wwwcache.sanger.ac.uk:3128/');
  
    my $response = $ua->get('http://ensembl.blogspot.com/rss.xml');
    my $rss = new XML::RSS;
    
    my $r = $rss->parse($response->decoded_content);
    
    $items = $rss->{'items'};
    $ENV{CACHE_TIMEOUT} = 3600;
    $MEMD->set('::BLOG', $items, $ENV{CACHE_TIMEOUT}, qw(STATIC BLOG))
      if $MEMD;
  }

  my $count = 3;
  if (@$items) {
    $html .= "<ul>\n";
    for (my $i = 0; $i < $count && $i < scalar(@$items);$i++) {
      my $item = $items->[$i];
      my $title = $item->{'title'};
      my $url   = $item->{'link'};
      my $date  = substr($item->{'pubDate'}, 0, 16);
      $html .= "<li>$date: <a href=\"$url\">$title</a></li>\n"; 
    }
    $html .= "</ul>\n";
  } else {
    $html .= qq(<p>Sorry, no feed is available from our blog at the moment</p>);
  }

  $html .= qq(<a href="http://ensembl.blogspot.com/">Go to Ensembl blog &rarr;</a>);

  return $html;
}

}

1;
