package EnsEMBL::Web::Data::View;

## Object representing help for an individual Ensembl view

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('help_record');
__PACKAGE__->set_primary_key('help_record_id');
__PACKAGE__->set_type('view');

__PACKAGE__->add_fields(
  ensembl_object => "enum('Location','Gene','Transcript','Variation','Regulation')",
  ensembl_action => 'string',
  content    => 'text',
);

__PACKAGE__->add_queriable_fields(
  keyword     => 'string',
  status      => "enum('draft','live','dead')",
  helpful     => 'int',
  not_helpful => 'int',
);

1;
