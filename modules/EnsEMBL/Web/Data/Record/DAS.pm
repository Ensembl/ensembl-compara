package EnsEMBL::Web::Data::Record::DAS;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('das');

__PACKAGE__->add_fields(
  url    => 'text',
  name   => 'text',
  config => 'text',
);

1;