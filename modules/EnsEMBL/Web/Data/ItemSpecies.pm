package EnsEMBL::Web::Data::ItemSpecies;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('item_species');
__PACKAGE__->set_primary_keys(qw/news_item_id species_id/);

__PACKAGE__->has_a(news_item => 'EnsEMBL::Web::Data::NewsItem');
__PACKAGE__->tie_a(species   => 'EnsEMBL::Web::Data::Species');

1;