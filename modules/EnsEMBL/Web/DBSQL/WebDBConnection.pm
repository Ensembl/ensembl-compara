package EnsEMBL::Web::DBSQL::WebDBConnection;

use strict;
use warnings;

sub import {
  my ($class, $species_defs) = @_;
  my $caller = caller;
  my $dsn = join(':',
    'dbi',
    'mysql',
    $species_defs->multidb->{'ENSEMBL_WEBSITE'}{'NAME'},
    $species_defs->multidb->{'ENSEMBL_WEBSITE'}{'HOST'},
    $species_defs->multidb->{'ENSEMBL_WEBSITE'}{'PORT'},
  );
  $caller->connection(
    $dsn,
    $species_defs->ENSEMBL_WRITE_USER,
    $species_defs->ENSEMBL_WRITE_PASS,
    {
      RaiseError => 1,
      PrintError => 1,
      AutoCommit => 1,
    }
  ) || die "Can not connect to $dsn";
}

1;