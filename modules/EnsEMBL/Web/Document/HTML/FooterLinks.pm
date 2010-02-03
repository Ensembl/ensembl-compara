package EnsEMBL::Web::Document::HTML::FooterLinks;

### Generates release info for the footer

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $sd = $self->species_defs;

  $self->printf(
    q(
  <div class="twocol-right right unpadded">%s release %d - %s</div>),
    $sd->ENSEMBL_SITE_NAME, $sd->ENSEMBL_VERSION, $sd->ENSEMBL_RELEASE_DATE
  );
}

1;

