package EnsEMBL::Web::Document::HTML::NewToEnsembl;

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
  my $hub            = $self->hub;
  my $sd             = $hub->species_defs;
  my $static_server  = $sd->ENSEMBL_STATIC_SERVER;
  my $img_url        = $sd->img_url;
  my $sitename       = $sd->ENSEMBL_SITETYPE;
  my $html           = ''; 

  $html .= qq(<h2>New to $sitename?</h2><div class="new-to-ensembl">);

  my @did_you_know = (
    '/info/website/tutorials/'                        => "Learn how to use $sitename"             => 'with our video tutorials and walk-throughs',
    '/info/website/help/control_panel.html#cp-data'   => 'Add custom tracks'                      => 'using our control panel',
    '/info/website/upload/index.html'                 => 'Upload and analyse your data'           => $sd->ENSEMBL_LOGINS ? "and save it to your $sitename account" : "and display it alongside $sitename data",
    $sd->ENSEMBL_BLAST_ENABLED ? (
    '/Multi/blastview'                                => 'Search for a DNA or protein sequence'   => 'using BLAST or BLAT'
    ) : (),
    '/info/data/api.html'                             => 'Fetch only the data you want'           => 'from our public database, using the Perl API',
    '/info/data/ftp/'                                 => 'Download our databases via FTP'         => 'in FASTA, MySQL and other formats',
    $sd->ENSEMBL_MART_ENABLED != 0 ? (
    '/biomart/martview'                               => "Mine $sitename with BioMart"            => 'and export sequences or tables in text, html, or Excel format'
    ) : ()
  );

  while (my ($url, $heading, $extra) = splice @did_you_know, 0, 3) {
    $html .= qq(<p><a href="$url">$heading</a><span>$extra</span></p>);
  }

  $html .= qq(</div><p>Still got questions? Try our <a href="/Help/Faq" class="popup">FAQs</a> or <a href="/Help/Glossary" class="popup">glossary</a></p>); 
   
  return $html;
}

1;
