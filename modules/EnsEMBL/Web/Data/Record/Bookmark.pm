package EnsEMBL::Web::Data::Record::Bookmark;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->set_type('bookmark');

__PACKAGE__->add_fields(
  url         => 'text',
  name        => 'text',
  shortname   => 'text',
  description => 'text',
  click       => 'int',
  object      => 'text',
);

1;