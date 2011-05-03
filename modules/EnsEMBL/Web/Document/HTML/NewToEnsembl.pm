package EnsEMBL::Web::Document::HTML::NewToEnsembl;

### This module outputs a list of tips plus a random item from the Wordpress "minifeed" RSS feed 

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
  my $self           = shift;
  my $hub            = new EnsEMBL::Web::Hub;
  my $sd             = $hub->species_defs;
  my $static_server  = $sd->ENSEMBL_STATIC_SERVER;
  my $img_url        = $sd->img_url;
  my $sitename       = $sd->ENSEMBL_SITETYPE;
  my $html           = '<h2 class="first">New to '.$sitename.'?</h2>'; 

  my $rss_url = $sd->ENSEMBL_TIPS_RSS;
  my $tips = $MEMD && $MEMD->get('::TIPS') || [];
  
  ## Check the cache, then fetch new tips
  unless (@$tips && $rss_url) {
    $tips = $self->get_rss_feed($hub, $rss_url);

    if ($tips && @$tips && $MEMD) {
      $MEMD->set('::TIPS', $tips, 3600, qw(STATIC TIPS));
    }
  }

  ## Now pick a random tip and display it
  if (scalar(@$tips)) {
    $html .= qq(<div class="info-box embedded-box float-right">
<h3 class="first">Did you know...?</h3>);

    my $random = int(rand(scalar(@$tips)));
    my $tip = $tips->[$random];
    $html .= $tip->{'content'};

    $html .= qq(\n</div>\n);
  }

  $html .= qq(
  <p>
Did you know you can:
</p>

<dl>
<dt><img src="${img_url}e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/info/website/tutorials/">Learn how to use $sitename</a></dt>
<dd>with our video tutorials and walk-throughs</dd>
<dt><img src="${img_url}e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/info/website/help/control_panel.html#cp-panel">Add custom tracks</a></dt>
<dd>using our new Control Panel</dd>
<dt><img src="${img_url}e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/info/website/upload/index.html">Upload and analyse your data</a></dt>
);
  if ($sd->ENSEMBL_LOGINS) {
    $html .= qq(<dd>and save it to your $sitename account</dd>);
  }
  else {
    $html .= qq(<dd>and display it alongside $sitename data</dd>);
  }
  if ($sd->ENSEMBL_BLAST_ENABLED) {
    $html .= qq(
<dt><img src="${img_url}e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/Multi/blastview">Search for a DNA or protein sequence</a></dt>
<dd>using BLAST or BLAT</dd>);
  }
  $html .= qq(
<dt><img src="${img_url}e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/info/data/api.html">Fetch only the data you want</a></dt>
<dd>from our public database, using the Perl API</dd>
<dt><img src="${img_url}e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/info/data/ftp/">Download our databases via FTP</a></dt>
<dd>in FASTA, MySQL and other formats</dd>
);
  if ($sd->ENSEMBL_MART_ENABLED != 0) {
    $html .= qq(<dt><img src="${img_url}e-quest.gif" style="width:20px;height:19px;vertical-align:middle;padding-right:4px" alt="(e?)" />
<a href="/biomart/martview">Mine $sitename with BioMart</a></dt>
<dd>and export sequences or tables in text, html, or Excel format</dd>
);
  }
  $html .= qq(</dl>

<p>Still got questions? Try our <a href="/Help/Faq" class="popup">FAQs</a> or <a href="/Help/Glossary" class="popup">glossary</a></p>
  );
  
  return $html;
}

1;
