package EnsEMBL::Web::Data::Record::URL;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('url');

__PACKAGE__->add_fields(
  url     => 'text',
);

1;
