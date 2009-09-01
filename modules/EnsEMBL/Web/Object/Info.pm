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


sub availability {
  my $self = shift;
  my $hash = $self->_availability;
  $hash->{'database.variation'} =
    exists $self->species_defs->databases->{'DATABASE_VARIATION'}  ? 1 : 0;
  return $hash;
}

sub short_caption { return 'About this species'; }
sub counts        { return undef; }


1;
