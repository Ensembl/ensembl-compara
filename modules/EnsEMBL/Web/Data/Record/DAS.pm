package EnsEMBL::Web::Data::Record::DAS;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('das');

__PACKAGE__->add_fields(
  logic_name  => 'text',
  url         => 'text',
  dsn         => 'text',
  maintainer  => 'text',
  description => 'text',
  on          => 'text',
  homepage    => 'text',
  label       => 'text',
  category    => 'text',
  coords      => 'text',
);

1;
