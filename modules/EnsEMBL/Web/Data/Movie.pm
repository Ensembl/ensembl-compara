package EnsEMBL::Web::Data::Movie;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('help_record');
__PACKAGE__->set_primary_key('help_record_id');
__PACKAGE__->set_type('movie');

__PACKAGE__->add_fields(
  title         => 'string',
  filename      => 'string',
  width         => 'int',
  height        => 'int',
  filesize      => 'float(3,1)',
  length        => 'string',
  list_position => 'int',
);

__PACKAGE__->add_queriable_fields(
  keyword     => 'string',
  status      => "enum('draft','live','dead')",
  helpful     => 'int',
  not_helpful => 'int',
);

1;
