package EnsEMBL::Web::Data::Record::Invite;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('invite');

__PACKAGE__->add_fields(
  email  => 'text',
  status => 'text',
  code   => 'text',
);

1;