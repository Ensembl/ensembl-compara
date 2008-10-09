package EnsEMBL::Web::Document::HTML::BreadCrumbs;
use strict;
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

### Package to generate breadcrumb links (currently incorporated into masthead)
### Limited to three levels in order to keep masthead neat :)

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render   {
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
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

  if ($species && $species ne 'multi') {
    if ($species eq 'common') {
      $html .= qq( &gt; <strong>Control Panel</strong>);
    }
    else {
      my $display_name = $species_defs->SPECIES_COMMON_NAME;
      if ($display_name =~ /\./) {
        $display_name = '<i>'.$display_name.'</i>'
      }
      if ($ENV{'ENSEMBL_TYPE'} eq 'Info') {
        $html .= qq( &gt; <strong>$display_name</strong>);
      }
      else {
        $html .= qq( &gt; <a href="/$species/Info/Index">).$display_name.qq(</a>);
      }
    }
  }
  elsif ($you_are_here =~ m#^/info/#) {

    ## Level 2 link
    if ($you_are_here eq '/info/' || $you_are_here eq '/info/index.html') {
      $html .= qq( &gt; <strong>Help &amp; Documentation</strong>);
    }
    else {
      $html .= qq( &gt; <strong><a href="/info/">Help &amp; Documentation</a></strong>);
    }

  }
  $_[0]->printf($html);
}

1;

