package EnsEMBL::Web::Data::Record::Mixer;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('mixer');

__PACKAGE__->add_fields(
  settings => 'text',
);

1;