package EnsEMBL::Web::Data::Record::Infobox;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('infobox');

__PACKAGE__->add_fields(
  name => 'text',
);

1;