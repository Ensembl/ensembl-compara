package EnsEMBL::Web::Data::Record::Drawer;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('drawer');

__PACKAGE__->add_fields(
  group => 'text',
);

1;