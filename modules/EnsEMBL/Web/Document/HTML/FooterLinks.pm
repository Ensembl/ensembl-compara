package EnsEMBL::Web::Document::HTML::FooterLinks;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $sd = $ENSEMBL_WEB_REGISTRY->species_defs;

  $_[0]->printf(
    q(
    <div class="twocol-right right unpadded">%s release %d - %s</div>),
    $sd->ENSEMBL_SITE_NAME, $sd->ENSEMBL_VERSION, $sd->ENSEMBL_RELEASE_DATE
  );
}

1;

