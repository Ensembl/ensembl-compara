
# Let the code begin...


package Bio::Search::HSP::StorableHSP;
use vars qw(@ISA);
use strict;

use Bio::Root::Storable;
use Bio::Search::HSP::GenericHSP;

@ISA = qw( Bio::Search::HSP::GenericHSP Bio::Root::Storable );

1;
