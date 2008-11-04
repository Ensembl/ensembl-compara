package EnsEMBL::Web::ViewConfig::Transcript::ExternalData;

use strict;
use warnings;

use base qw(EnsEMBL::Web::ViewConfig::Gene::ExternalData);

## SEE SUPERCLASS FOR PRIMARY FUNCTIONALITY ##

sub _view {
  return 'Transcript/ExternalData';
}


1;