package EnsEMBL::Web::Data::Category;

use strict;
use warnings;
use base qw(EnsEMBL::Web::CDBI);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('category');
__PACKAGE__->set_primary_key('category_id');

__PACKAGE__->add_queriable_fields(
  name     => 'string',
  priority => 'int',
);

__PACKAGE__->has_many(articles => 'EnsEMBL::Web::Data::Article');

1;
