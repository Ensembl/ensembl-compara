package EnsEMBL::Web::DBSQL::UserDBConnection;

use strict;
use warnings;
use EnsEMBL::Web::Cache;

our $cache = new EnsEMBL::Web::Cache;

sub import {
  my ($class, $species_defs) = @_;
  my $caller = caller;
  my $dsn = join(':',
    'dbi',
    'mysql',
    $species_defs->ENSEMBL_USERDB_NAME,
    $species_defs->ENSEMBL_USERDB_HOST,
    $species_defs->ENSEMBL_USERDB_PORT,
  );
  $caller->connection(
    $dsn,
    $species_defs->ENSEMBL_USERDB_USER,
    $species_defs->ENSEMBL_USERDB_PASS,
    {
      RaiseError => 1,
      PrintError => 1,
      AutoCommit => 1,
    }
  ) || die "Can not connect to $dsn";

  $caller->cache($cache)
    if $cache;
}

1;
