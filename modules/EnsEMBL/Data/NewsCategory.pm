package EnsEMBL::Data::NewsCategory;

### NAME: EnsEMBL::Data::NewsCategory
### ORM class for the news_category table in ensembl_website 

### STATUS: Under Development

### DESCRIPTION:

use strict;
use warnings;
use base qw(EnsEMBL::Data);

__PACKAGE__->meta->setup(
  table       => 'news_category',
  columns     => [
    news_category_id  => {'type' => 'serial', 'primary_key' => 1, 'not_null' => 1}, 
    code              => {'type' => 'varchar', 'length' => 10},
    name              => {'type' => 'varchar', 'length' => 64},
    priority          => {'type' => 'tinyint'},
  ],

  relationships => [
    news_item => {
      'type'        => 'one to many',
      'class'       => 'EnsEMBL::Data::NewsItem',
      'column_map'  => {'news_category_id' => 'news_category_id'},
    },
  ], 
);


1;
