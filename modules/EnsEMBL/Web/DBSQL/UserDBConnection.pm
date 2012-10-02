package EnsEMBL::Web::DBSQL::UserDBConnection;

use strict;
use warnings;
use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::DBSQL::DirectDBConnection);

our $cache = new EnsEMBL::Web::Cache;

my $dbh;

sub import {
  my ($class,$species_defs) = @_;

  my $caller = caller;
  $class->direct_connection($caller,
                            $species_defs->ENSEMBL_USERDB_NAME,
                            $species_defs->ENSEMBL_USERDB_HOST,
                            $species_defs->ENSEMBL_USERDB_PORT,
                            $species_defs->ENSEMBL_USERDB_USER,
                            $species_defs->ENSEMBL_USERDB_PASS);
  $caller->cache($cache) if $cache;
}

1;
