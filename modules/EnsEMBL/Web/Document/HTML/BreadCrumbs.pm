package EnsEMBL::Web::Document::HTML::BreadCrumbs;
use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render   {
  my $you_are_here = $ENV{'SCRIPT_NAME'};
  my $html;
  if ($you_are_here eq '/index.html') {
    $html = qq(<strong>Home</strong>);
  }
  else {
    $html = qq(<a href="/">Home</a>);
  }
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
    if ($you_are_here eq '/info/index.html') {
      $html .= qq( &gt; <strong>Documentation</strong>);
    }
    else {
      $html .= qq( &gt; <a href="/info/">Documentation</a>);
    }
  }
  $_[0]->printf($html);
}

1;

