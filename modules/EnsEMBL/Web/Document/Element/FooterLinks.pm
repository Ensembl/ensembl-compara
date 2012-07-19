# $Id$

package EnsEMBL::Web::Document::Element::FooterLinks;

### Generates release info for the footer

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub content {
  my $species_defs = shift->species_defs;
  return sprintf '<div class="column-two right"><p>%s release %d - %s</p></div>', $species_defs->ENSEMBL_SITE_NAME, $species_defs->ENSEMBL_VERSION, $species_defs->ENSEMBL_RELEASE_DATE
}

1;
