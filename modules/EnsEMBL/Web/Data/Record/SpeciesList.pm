package EnsEMBL::Web::Data::Record::SpeciesList;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('specieslist');

__PACKAGE__->add_fields(
  list       => 'text',
  favourites => 'text',
);

1;