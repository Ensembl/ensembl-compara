package EnsEMBL::Web::Document::HTML::FooterLinks;

### Generates release info for the footer

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $sd = shift->species_defs;

  $_[0]->printf(
    q(
  <div class="twocol-right right unpadded">%s release %d - %s</div>),
    $sd->ENSEMBL_SITE_NAME, $sd->ENSEMBL_VERSION, $sd->ENSEMBL_RELEASE_DATE
  );
}

1;

