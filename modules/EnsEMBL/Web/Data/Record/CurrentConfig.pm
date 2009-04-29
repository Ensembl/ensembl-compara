package EnsEMBL::Web::Data::Record::CurrentConfig;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->set_type('currentconfig');

__PACKAGE__->add_fields(
  config => 'text',
);

1;