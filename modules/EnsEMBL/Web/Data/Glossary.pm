package EnsEMBL::Web::Data::Glossary;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('help_record');
__PACKAGE__->set_primary_key('help_record_id');
__PACKAGE__->set_type('glossary');


__PACKAGE__->add_fields(  
    word     => 'tinytext',
    expanded => 'tinytext',
    meaning  => 'text'
);

__PACKAGE__->add_queriable_fields(
  keyword     => 'string',
  status      => "enum('draft','live','dead')",
  helpful     => 'int',
  not_helpful => 'int',
);

1;