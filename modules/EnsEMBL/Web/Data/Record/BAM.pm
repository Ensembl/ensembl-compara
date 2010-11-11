package EnsEMBL::Web::Data::Record::BAM;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->set_type('bam');

__PACKAGE__->add_fields(
  url       => 'text',
  species   => 'text',
  code      => 'text',
  name      => 'text',
  nearest   => 'text',
);

1;
