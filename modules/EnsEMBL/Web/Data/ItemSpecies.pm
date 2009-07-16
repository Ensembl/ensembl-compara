package EnsEMBL::Web::Data::ItemSpecies;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('item_species');
__PACKAGE__->set_primary_key('item_species_id');

__PACKAGE__->add_queriable_fields(
  news_item_id => 'int',
  species_id   => 'int',
);

__PACKAGE__->has_a(news_item => 'EnsEMBL::Web::Data::NewsItem');
__PACKAGE__->tie_a(species   => 'EnsEMBL::Web::Data::Species');

1;