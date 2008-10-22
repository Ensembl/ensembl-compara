package EnsEMBL::Web::Data::Record::Upload;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('upload');

__PACKAGE__->add_fields(
  filename => 'text',
  format   => 'text',
  species  => 'text',
  share_id => 'int',
  assembly => 'text',
);

1;
