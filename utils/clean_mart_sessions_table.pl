#!/usr/local/bin/perl

use strict;

use DBI;
use File::Basename qw(dirname);
use FindBin qw($Bin);

BEGIN {
  my $serverroot = dirname($Bin);
  unshift @INC, "$serverroot/conf", $serverroot;
  
  require SiteDefs;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;

  require EnsEMBL::Web::Hub;
}

my $hub = new EnsEMBL::Web::Hub;
my $sd  = $hub->species_defs;

my $dbh = DBI->connect(
  sprintf('DBI:mysql:database=%s;host=%s;port=%s', $sd->ENSEMBL_USERDB_NAME, $sd->ENSEMBL_USERDB_HOST, $sd->ENSEMBL_USERDB_PORT),
  $sd->ENSEMBL_USERDB_USER, $sd->ENSEMBL_USERDB_PASS
);

$dbh->do('DELETE from sessions WHERE modified_at < DATE(NOW()) - INTERVAL 1 WEEK');

# Optimise table on Sundays
if (!(gmtime)[6]) {
  $dbh->do('OPTIMIZE TABLE sessions');
}
  
$dbh->disconnect;
