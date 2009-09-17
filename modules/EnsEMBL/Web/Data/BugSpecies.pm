package EnsEMBL::Web::Data::BugSpecies;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('bug_species');
__PACKAGE__->set_primary_keys(qw/bug_id species_id/);

__PACKAGE__->has_a(bug      => 'EnsEMBL::Web::Data::Bug');
__PACKAGE__->tie_a(species  => 'EnsEMBL::Web::Data::Species');

1;
