package EnsEMBL::Web::Document::HTML::Copyright;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

@EnsEMBL::Web::Document::HTML::Copyright::ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  my @time   = localtime();
  my $sd     = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $year_0 = $sd->ENSEMBL_COPYRIGHT_YEAR || 2000;
  my $year_n = $time[5] + 1900;
     $year_n = sprintf("%02d", $year_n % 100) if int($year_n/100)==int($year_0/100) ;
  my $root = $sd->ENSEMBL_WEB_ROOT;
  my @Q = ();
  my $X = 1;
  while( my $T = $sd->get_config( 'MULTI', 'ENSEMBL_INSTITUTE_'.$X ) ) {
    push @Q, $T;
    $X++;
  }
  my $logo_links = join ' / ', @Q;
  $_[0]->printf( q(
    &copy; %s-%s %s - 
    %s is available to <a href="%sinfo/data/download.html">download for public use</a> -
    please see the <a href="%sinfo/about/code_licence.html">code licence</a> for details.
  ),
    $year_0, $year_n, $logo_links, $sd->ENSEMBL_SITE_NAME, $root, $root
  );
}

1;

