package EnsEMBL::Web::Data::BugRelease;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('bug_release');
__PACKAGE__->set_primary_keys(qw/bug_id release_id/);

__PACKAGE__->has_a(bug      => 'EnsEMBL::Web::Data::Bug');
__PACKAGE__->tie_a(release  => 'EnsEMBL::Web::Data::Release');

1;
