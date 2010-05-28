package EnsEMBL::Data::Changelog;

### NAME: EnsEMBL::Data::Changelog
### ORM class for the changelog table in ensembl_production 

### STATUS: Under Development

### DESCRIPTION:

### TODO - add relationships to Species

use strict;
use warnings;
use base qw(EnsEMBL::Data);

## Define schema
__PACKAGE__->meta->setup(
  table       => 'changelog',

  columns     => [
    changelog_id      => {type => 'serial', primary_key => 1, not_null => 1}, 
    release_id        => {type => 'integer'},
    title             => {type => 'text'},
    content           => {type => 'text'},
    notes             => {type => 'text'},
    status            => {type => 'enum', 'values' => [qw(declared handed_over postponed cancelled)]},
    team              => {type => 'enum', 'values' => [qw(Compara Core Funcgen Genebuild Mart Outreach Variation Web)]},
    assembly          => {type => 'enum', 'values' => [qw(N Y)]},
    gene_set          => {type => 'enum', 'values' => [qw(N Y)]},
    repeat_masking    => {type => 'enum', 'values' => [qw(N Y)]},
    stable_id_mapping => {type => 'enum', 'values' => [qw(N Y)]},
    affy_mapping      => {type => 'enum', 'values' => [qw(N Y)]},
    db_status         => {type => 'enum', 'values' => [qw(new patched)]},
    created_by        => {type => 'integer'},
    created_at        => {type => 'datetime'},
    modified_by       => {type => 'integer'},
    modified_at       => {type => 'datetime'},
  ],

);

## Define which db connection to use
sub init_db { EnsEMBL::Data::DBSQL::RoseDB->new('production'); }

1;
