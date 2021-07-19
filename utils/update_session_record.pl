#!/usr/local/bin/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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
  
  require SiteDefs; SiteDefs->import;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;

  require EnsEMBL::Web::SpeciesDefs;
}

my $time  = Time::HiRes::time;
my $sd    = EnsEMBL::Web::SpeciesDefs->new;
my $db    = $sd->session_db;

my $dsn = sprintf(
  'DBI:mysql:database=%s;host=%s;port=%s',
  $db->{'NAME'},
  $db->{'HOST'},
  $db->{'PORT'},
);

my $dbh = DBI->connect(
  $dsn, $db->{'USER'}, $db->{'PASS'}
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
