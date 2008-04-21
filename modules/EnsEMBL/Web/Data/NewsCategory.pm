package EnsEMBL::Web::Data::NewsCategory;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('news_category');

__PACKAGE__->set_primary_key('news_category_id');

__PACKAGE__->add_queriable_fields(
  code     => 'varchar(10)',
  name     => 'varchar(64)',
  priority => 'tinyint',
);

__PACKAGE__->has_many(news_items => 'EnsEMBL::Web::Data::NewsItem');

1;