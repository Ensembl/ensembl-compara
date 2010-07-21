package EnsEMBL::Web::Data::Record::Sortable;

## no longer in use - part of old slide-down user account panel

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->set_type('sortable');

__PACKAGE__->add_fields(
  kind => 'text',
);

1;
