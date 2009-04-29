package EnsEMBL::Web::Data::Record::Sortable;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->set_type('sortable');

__PACKAGE__->add_fields(
  kind => 'text',
);

1;