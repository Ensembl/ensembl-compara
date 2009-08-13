package EnsEMBL::Web::Object::Info;

### Stub needed by dynamic home page code

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Object);
use EnsEMBL::Web::RegObj;

sub caption {
  my $self   = shift;
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  return 'Search '.$species_defs->ENSEMBL_SITETYPE
    .' '.$species_defs->get_config($self->species, 'SPECIES_COMMON_NAME');
}


sub short_caption { return 'About this species'; }
sub counts        { return undef; }


1;
