package EnsEMBL::Web::Document::HTML::DidYouKnow;

### This module outputs a list of tips plus a random item from the Wordpress "minifeed" RSS feed 

use strict;
use warnings;

use LWP::UserAgent;
use Encode qw(encode_utf8);

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::Document::HTML);

our $MEMD = EnsEMBL::Web::Cache->new(
  enable_compress    => 1,
  compress_threshold => 10_000,
);

sub render {
  my $self           = shift;
  my $hub            = EnsEMBL::Web::Hub->new;
  my $sd             = $hub->species_defs;
  my $static_server  = $sd->ENSEMBL_STATIC_SERVER;
  my $img_url        = $sd->img_url;
  my $sitename       = $sd->ENSEMBL_SITETYPE;
  my $html           = ''; 

  my $rss_url = $sd->ENSEMBL_TIPS_RSS;
  my $tips = $MEMD && $MEMD->get('::TIPS') || [];
  
  ## Check the cache, then fetch new tips
  unless (@$tips && $rss_url) {
    $tips = $self->get_rss_feed($hub, $rss_url);

    if ($tips && @$tips) {
      $_->{'content'} = encode_utf8($_->{'content'}) for @$tips;
      $MEMD->set('::TIPS', $tips, 3600, qw(STATIC TIPS)) if $MEMD;
    }
  }

  ## Now pick a random tip and display it
  if (scalar(@$tips)) {
    $html .= sprintf q(<div class="info-box did-you-know"><h3>Did you know&hellip;?</h3>%s</div>), $tips->[ int(rand(scalar(@$tips))) ]->{'content'};
  }

  return $html;
}

1;
