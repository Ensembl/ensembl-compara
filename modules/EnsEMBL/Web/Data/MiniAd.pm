package EnsEMBL::Web::Data::MiniAd;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::UserDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('miniad');
__PACKAGE__->set_primary_key('miniad_id');

__PACKAGE__->add_queriable_fields(
  image      => 'varchar(32)',
  alt        => 'tinytext',
  url        => 'tinytext',
  start_date => 'date',
  end_date   => 'date',
);

1;