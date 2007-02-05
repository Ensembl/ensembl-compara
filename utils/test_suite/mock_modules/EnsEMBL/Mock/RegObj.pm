package EnsEMBL::Mock::RegObj;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Mock::Registry;

{

sub mock_registry {
  return EnsEMBL::Mock::Registry->new();
}

}


1;
