package EnsEMBL::Data::NewsItem;

### NAME: EnsEMBL::Data::NewsItem
### ORM class for the news_item table in ensembl_website 

### STATUS: Under Development

### DESCRIPTION:

use strict;
use warnings;
use base qw(EnsEMBL::Data);

__PACKAGE__->meta->setup(
  table       => 'news_item',

  columns     => [
    news_item_id  => {type => 'serial', primary_key => 1, not_null => 1}, 
    title         => {type => 'tinytext'},
    content       => {type => 'text'},
    priority      => {type => 'int'},
    status        => {type => 'enum'},
  ],

  foreign_keys => [
    news_category => {
      'class' => 'EnsEMBL::Data::NewsCategory',
      'key_columns' => {'news_category_id' => 'news_category_id'},
    },
  ],

);

=pod
### TODO - other relationships
__PACKAGE__->has_a(release       => 'EnsEMBL::Web::Data::Release');
__PACKAGE__->has_many(species    => 'EnsEMBL::Web::Data::Species');
=cut



1;
