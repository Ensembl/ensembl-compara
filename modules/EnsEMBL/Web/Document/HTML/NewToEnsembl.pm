package EnsEMBL::Web::Document::HTML::NewToEnsembl;

### This module outputs a list of tips plus a random Tweet (for the home page), 

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request;
use XML::Simple;
use Data::Dumper;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::Root);

our $MEMD = EnsEMBL::Web::Cache->new();

srand;

{

sub render {
  my $self  = shift;
  ## Ensembl twitter feet (twitter.com/ensembl)

  my $html = '<h2 class="first">New to Ensembl?</h2>'; 
  my @generic_images = qw(new data help);

  my $tweets = $MEMD && $MEMD->get('::TWEETS') || [];
  
  ## Check the cache, then fetch new tweets
  unless (@$tweets) {
    my $username = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_TWITTER_USER;
    my $password = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_TWITTER_PASS;
    my $since_id = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_TWITTER_SINCE_ID;

    my @species = map { local $_ = $_; s/_/ /g; $_ } $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->valid_species;
    my $regex = join('|', @species);

    if ($username && $password) {
      ## Fetch our own Twitter feed
      my $ua = new LWP::UserAgent;
      my $proxy = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WWW_PROXY;
      $ua->proxy( 'http', $proxy ) if $proxy;
      $ua->credentials('twitter.com:80', 'Twitter API', $username, $password);

      my $url = 'http://twitter.com/statuses/user_timeline.xml?count=5';
      if ($since_id) {
        $url .= '&since_id='.$since_id;
      }
      my $request = HTTP::Request->new(GET => $url);
      my $response = $ua->request($request);
      my $parser = new XML::Simple;
      my $tweet;

      ## Parse feed
      if ($response->is_success) {
        my $xml = $parser->XMLin($response->content);        
        my $update = $xml->{'status'};
        while (my ($id, $details) = each (%$update)) {
          my $tweet = $details->{'text'};
          my $miniad;
          ## Add an image
          if ($tweet =~ s/(\[\w+\])// ) { ## File name (sans extension) in square brackets
            (my $image = $1) =~ s/\[|\]//g;
            $miniad .= qq(<img src="/img/miniad/$image.gif" alt="" class="float-right" />);
          }
          elsif ($tweet =~ /($regex)/) {
            (my $species = $1) =~ s/ /_/;
            $miniad .= qq(<img src="/img/species/thumb_$species.png" alt="" class="float-right" />);
          }
          else {
            my $random = int(rand(scalar(@generic_images)));
            my $image = $generic_images[$random];
            $miniad .= qq(<img src="/img/miniad/$image.gif" alt="" class="float-right" />);
          }
          ## Turn URLs into links
          $tweet =~ s/(http:\/\/[\w|-|\.|\/]+)/<a href="$1">$1<\/a>/g;
          $miniad .= $tweet;
          push @$tweets, $miniad;
        }
      }

      $MEMD->set('::TWEETS', $tweets, 3600, qw(STATIC TWEETS)) if $MEMD;
    }
  }

  ## Now pick a random Tweet and display it
  if (scalar(@$tweets)) {
    $html .= qq(<div class="info-box embedded-box float-right">
<h3 class="first">Did you know...?</h3>);

    my $random = int(rand(scalar(@$tweets)));
    $html .= $tweets->[$random];

    $html .= qq(\n</div>\n);
  }

  $html .= qq(
  <p>
Did you know you can:
</p>

<dl>
<dt><img src="/i/e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/info/website/tutorials/">Learn how to use Ensembl</a></dt>
<dd>with our video tutorials and walk-throughs</dd>
<dt><img src="/i/e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/info/website/help/control_panel.html#cp-panel">Add custom tracks</a></dt>
<dd>using our new Control Panel</dd>
<dt><img src="/i/e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/info/website/help/control_panel.html#cp-data">Upload your own data</a></dt>
<dd>and save it to your Ensembl account</dd>
<dt><img src="/i/e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/Multi/blastview">Search for a DNA or protein sequence</a></dt>
<dd>using BLAST or BLAT</dd>
<dt><img src="/i/e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/info/data/api.html">Fetch only the data you want</a></dt>
<dd>from our public database, using the Ensembl Perl API</dd>
<dt><img src="/i/e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/info/data/ftp/">Download our databases via FTP</a></dt>
<dd>in FASTA, MySQL and other formats</dd>
<dt><img src="/i/e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/biomart/martview">Mine Ensembl with BioMart</a></dt>
<dd>and export sequences or tables in text, html, or Excel format</dd>
</dl>

<p>Still got questions? <a href="/Help/Faq" class="modal_link">Try our FAQs</a></p>
  );
  
  return $html;
}

}

1;
