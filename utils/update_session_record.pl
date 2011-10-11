#!/usr/local/bin/perl

use strict;

use DBI;
use File::Basename qw(dirname);
use FindBin qw($Bin);
use Data::Dumper;
use Time::HiRes;
$Data::Dumper::Indent   = 0;
$Data::Dumper::Maxdepth = 0;

BEGIN {
  my $serverroot = dirname($Bin);
  unshift @INC, "$serverroot/conf", $serverroot;
  
  require SiteDefs;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;

  require EnsEMBL::Web::Hub;
}

my $time = Time::HiRes::time;
my $hub = new EnsEMBL::Web::Hub;
my $sd  = $hub->species_defs;

my $dbh = DBI->connect(
  sprintf('DBI:mysql:database=%s;host=%s;port=%s', $sd->ENSEMBL_USERDB_NAME, $sd->ENSEMBL_USERDB_HOST, $sd->ENSEMBL_USERDB_PORT),
  $sd->ENSEMBL_USERDB_USER, $sd->ENSEMBL_USERDB_PASS
);

$dbh->do('CREATE TABLE session_record_tmp LIKE session_record');
$dbh->do('INSERT INTO session_record_tmp SELECT * FROM session_record');

my $sth = $dbh->prepare('SELECT session_record_id, session_id, code, data FROM session_record_tmp WHERE type="nav"');
$sth->execute;

my %records;
my %valid_species = map { $_ => 1 } $sd->valid_species, 'Multi', 'common';
my @to_delete;

foreach (@{$sth->fetchall_arrayref}) {
  my ($session_record_id, $session_id, $code, $data_string) = @$_;
  
  my @new_code = split '/', $code;
  shift @new_code;
  shift @new_code if $valid_species{$new_code[0]};
  
  my $data = eval $data_string;
  
  $records{$session_id}{$new_code[0]} = { %{$records{$session_id}{$new_code[0]} || {}}, %$data };
  
  if ($records{$session_id}{'session_record_id'}{$new_code[0]}) {
    push @to_delete, $session_record_id;
  } else {
    $records{$session_id}{'session_record_id'}{$new_code[0]} = $session_record_id;
  }
}

foreach my $session_id (keys %records) {
  foreach (keys %{$records{$session_id}{'session_record_id'}}) {
    (my $data = Dumper $records{$session_id}{$_}) =~ s/^\$VAR1 = //;
    $dbh->do(sprintf 'UPDATE session_record_tmp SET code="%s", data="%s" WHERE session_record_id=%s', $_, $dbh->quote($data), $records{$session_id}{'session_record_id'}{$_});
  }
}

$dbh->do(sprintf 'DELETE FROM session_record_tmp WHERE session_record_id in (%s)', join ',', @to_delete);

$dbh->do('RENAME TABLE session_record TO session_record2, session_record_tmp TO session_record');
#$dbh->do('DROP TABLE session_record2'); ********* DO THIS MANUALLY ONCE YOU'VE CHECKED EVERYTHING IS OK *********
$dbh->disconnect;
