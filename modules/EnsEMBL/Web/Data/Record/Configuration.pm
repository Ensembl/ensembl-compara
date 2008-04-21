package EnsEMBL::Web::Data::Record::Configuration;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('configuration');

__PACKAGE__->add_fields(
  scriptconfig => 'text',
  url          => 'text',
  name         => 'text',
  description  => 'text',
);

1;