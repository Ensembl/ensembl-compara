package EnsEMBL::Web::Document::HTML::BreadCrumbs;
use strict;
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

### Package to generate breadcrumb links (currently incorporated into masthead)
### Limited to three levels in order to keep masthead neat :)

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render   {
  my $sd = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $you_are_here = $ENV{'SCRIPT_NAME'};
  my $html;

  ## Link to home page
  if ($you_are_here eq '/index.html') {
    $html = qq(<strong>Home</strong>);
  }
  else {
    $html = qq(<a href="/">Home</a>);
  }

  ## Species/static content links
  my $species = $ENV{'ENSEMBL_SPECIES'};
  if ($species) {
    if ($you_are_here eq '/'.$species.'/index.html') {
      $html .= qq( &gt; <strong>$species</strong>);
    }
    else {
      $html .= qq( &gt; <a href="/$species/">).$species.qq(</a>);
    }
  }
  elsif ($you_are_here =~ m#^/info/#) {

    ## Level 2 link
    if ($you_are_here eq '/info/index.html') {
      $html .= qq( &gt; <strong>Documentation</strong>);
    }
    else {
      $html .= qq( &gt; <a href="/info/">Documentation</a>);
    }

    ## Level 3 link - TO DO
  }
  $_[0]->printf($html);
}

1;

