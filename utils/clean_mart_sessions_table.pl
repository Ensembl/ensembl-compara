#!/usr/local/bin/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

BEGIN {
  my $serverroot = dirname($Bin);
  unshift @INC, "$serverroot/conf", $serverroot;
  
  require SiteDefs; SiteDefs->import;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;

  require EnsEMBL::Web::SpeciesDefs;
}

my $db  = EnsEMBL::Web::SpeciesDefs->new->session_db;
my $dbh = DBI->connect(sprintf('DBI:mysql:database=%s;host=%s;port=%s', $db->{'NAME'}, $db->{'HOST'}, $db->{'PORT'}), $db->{'USER'}, $db->{'PASS'});

$dbh->do('DELETE from sessions WHERE modified_at < DATE(NOW()) - INTERVAL 1 WEEK');

# Optimise table on Sundays
if (!(gmtime)[6]) {
  $dbh->do('OPTIMIZE TABLE sessions');
}

$dbh->disconnect;
