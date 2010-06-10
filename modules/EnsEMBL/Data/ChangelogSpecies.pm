package EnsEMBL::Data::ChangelogSpecies;

### NAME: EnsEMBL::Data::ChangelogSpecies
### ORM class defining the changelog_species table in ensembl_production 

### STATUS: Under Development

### DESCRIPTION:

use strict;
use warnings;
use base qw(EnsEMBL::Data);

## Define schema
__PACKAGE__->meta->setup(
  table       => 'changelog_species',

  columns     => [
    changelog_id      => {type => 'int', not_null => 1}, 
    species_id        => {type => 'int', not_null => 1}, 
  ],

  primary_key_columns => ['changelog_id', 'species_id'],

  relationships => [
    changelog => {
      'type'        => 'many to one',
      'class'       => 'EnsEMBL::Data::Changelog',
      'column_map'  => {'changelog_id' => 'changelog_id'},
    },
    species => {
      'type'        => 'many to one',
      'class'       => 'EnsEMBL::Data::ProductionSpecies',
      'column_map'  => {'species_id' => 'species_id'},
    },
  ],

);

## Define which db connection to use
sub init_db { EnsEMBL::Data::DBSQL::RoseDB->new('production'); }


1;
