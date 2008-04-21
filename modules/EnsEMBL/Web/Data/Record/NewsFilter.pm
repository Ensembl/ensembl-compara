package EnsEMBL::Web::Data::Record::NewsFilter;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('newsfilter');

__PACKAGE__->add_fields(
  species => 'text',
);

1;