package EnsEMBL::Web::Document::HTML::Blog;

### This module outputs a selection of news headlines for the home page, 
### based on the user's settings or a default list

use strict;
use warnings;

use LWP::UserAgent qw();
use XML::Atom::Feed;
use Data::Dumper;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::Root);

our $MEMD = EnsEMBL::Web::Cache->new(
  enable_compress    => 1,
  compress_threshold => 10_000,
);


{

sub render {
  my $self  = shift;
  
  ## Ensembl blog (ensembl.blogspot.com)
  my $html = qq(<h2>Latest Blog Entries</h2>);

  my @entries = $MEMD ? (@{ $MEMD->get('::BLOG') || [] }) : ();

  unless (@entries) {
    my $ua = new LWP::UserAgent;

    my $proxy = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WWW_PROXY;
    $ua->proxy( 'http', $proxy ) if $proxy;
  
    my $response = $ua->get('http://ensembl.blogspot.com/rss.xml');
    my $feed = XML::Atom::Feed->new(\$response->decoded_content);
    
    @entries = $feed->entries;
    
    $ENV{CACHE_TIMEOUT} = 3600;
    $MEMD->set('::BLOG', \@entries, $ENV{CACHE_TIMEOUT}, qw(STATIC BLOG))
      if $MEMD;
  }

  my $count = 3;
  if (@entries) {
    $html .= "<ul>\n";
    for (my $i = 0; $i < $count && $i < scalar(@entries);$i++) {
      my $title = $entries[$i]->title;
      my $url   = $entries[$i]->link->href;
      my $date  = substr($entries[$i]->updated, 0, 10);

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
