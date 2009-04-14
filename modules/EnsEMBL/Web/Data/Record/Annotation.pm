package EnsEMBL::Web::Data::Record::Annotation;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('annotation');

__PACKAGE__->add_fields(
  stable_id  => 'text',
  title      => 'text',
  ftype      => 'text',
  species    => 'text',
  annotation => 'text',
);

1;
