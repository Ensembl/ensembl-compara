package EnsEMBL::Web::Data::Record::Opentab;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('opentab');

__PACKAGE__->add_fields(
  name => 'text',
  tab  => 'text',
);

1;