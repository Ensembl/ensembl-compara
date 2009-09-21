package EnsEMBL::Web::Data::HelpLink;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('help_link');
__PACKAGE__->set_primary_key(qw/help_link_id/);

__PACKAGE__->add_queriable_fields(
  page_url          => 'string',
  help_record_id     => 'int'
);

1;
