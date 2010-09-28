# $Id$

package EnsEMBL::Web::Document::HTML::FooterLinks;

### Generates release info for the footer

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub _content {
  my $species_defs = shift->species_defs;
  return sprintf '<div class="twocol-right right unpadded">%s release %d - %s</div>', $species_defs->ENSEMBL_SITE_NAME, $species_defs->ENSEMBL_VERSION, $species_defs->ENSEMBL_RELEASE_DATE
}

1;

