package EnsEMBL::Web::ViewConfig::Variation::ExternalData;

use strict;
use warnings;

use EnsEMBL::Web::ViewConfig::Gene::ExternalData qw(form init);


## SEE SUPERCLASS FOR PRIMARY FUNCTIONALITY ##

sub _view {
  return 'Variation/ExternalData';
}


1;
