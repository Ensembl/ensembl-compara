package EnsEMBL::Web::Object::Info;

### Stub needed by dynamic home page code

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Object);

sub caption       { 
  my $self = shift;
  return $self->species_defs->ENSEMBL_SITETYPE.' '.$self->species_defs->SPECIES_COMMON_NAME.' (<i>'.$self->species_defs->SPECIES_BIO_NAME.'</i>)';
}
sub short_caption { return 'About this species'; }
sub counts        { return undef; }


1;
