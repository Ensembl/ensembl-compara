package EnsEMBL::Web::Document::HTML::NewToEnsembl;

### This module outputs a list of tips plus a random Tweet (for the home page), 

use strict;
use warnings;

#use Net::Twitter::Lite;
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
  ## Ensembl twitter feet (twitter.com/ensembl)

  my $html = '<h2 class="first">New to Ensembl?</h2>'; 

=pod
  my @tweets;
  my $cached;# = $MEMD && $MEMD->get('::TWEETS') || '';
  
  ## Check the cache, then fetch new tweets
  if ($cached) {
    @tweets = split('\n', $cached);
  }
  else {
    my $username = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_TWITTER_USER;
    my $password = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_TWITTER_PASS;
    if ($username && $password) {
      my $nt = Net::Twitter->new(
        traits    => [qw/API::REST/],
        username  => $username,
        password  => $password,
      );
    
      my $response = eval {$nt->friends_timeline({count => 5)};
      foreach my $update (@$responses) {
        warn "TWEET! ".$update->{'text'};  
      }
  
      #$MEMD->set('::TWEETS', $tweets, 3600, qw(STATIC BLOG)) if $MEMD;
    }
  }

  ## Now pick a random Tweet and display it
  if ($tweets) {
    $html = qq(<div class="info-box embedded-box float-right">);


    $html .= qq(<a href="http://twitter.com/ensembl">More updates from Twitter &rarr;</a>
    </div>);
  }
=cut

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
