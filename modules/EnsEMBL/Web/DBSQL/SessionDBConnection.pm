package EnsEMBL::Web::DBSQL::SessionDBConnection;

use strict;
use warnings;
use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::DBSQL::DirectDBConnection);

our $cache = EnsEMBL::Web::Cache->new;

sub import {
  my ($class, $species_defs) = @_;

  my $caller = caller;
  $class->direct_connection($caller,
                            $species_defs->multidb->{'DATABASE_SESSION'}{'NAME'} || $species_defs->ENSEMBL_USERDB_NAME,
                            $species_defs->multidb->{'DATABASE_SESSION'}{'HOST'} || $species_defs->ENSEMBL_USERDB_HOST,
                            $species_defs->multidb->{'DATABASE_SESSION'}{'PORT'} || $species_defs->ENSEMBL_USERDB_PORT,
                            $species_defs->multidb->{'DATABASE_SESSION'}{'USER'} || $species_defs->DATABASE_WRITE_USER,
                            $species_defs->multidb->{'DATABASE_SESSION'}{'PASS'} || $species_defs->DATABASE_WRITE_PASS);

  $caller->cache($cache) if $cache;
}

1;
