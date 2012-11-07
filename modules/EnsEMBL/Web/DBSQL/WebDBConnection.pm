package EnsEMBL::Web::DBSQL::WebDBConnection;

use strict;
use warnings;
use EnsEMBL::Web::Cache;

use base qw(EnsEML::Web::DBSQL::DirectDBConnection);

our $cache = EnsEMBL::Web::Cache->new;

sub import {
  my ($class, $species_defs) = @_;

  my $caller = caller;
  $class->direct_connection($caller,
                            $species_defs->multidb->{'DATABASE_WEBSITE'}{'NAME'},
                            $species_defs->multidb->{'DATABASE_WEBSITE'}{'HOST'},
                            $species_defs->multidb->{'DATABASE_WEBSITE'}{'PORT'},
                            $species_defs->multidb->{'DATABASE_WEBSITE'}{'USER'} || $species_defs->DATABASE_WRITE_USER,
                            defined $species_defs->multidb->{'DATABASE_WEBSITE'}{'PASS'} ? $species_defs->multidb->{'DATABASE_WEBSITE'}{'PASS'} : $species_defs->DATABASE_WRITE_PASS);

  $caller->cache($cache) if $cache;
}

1;
