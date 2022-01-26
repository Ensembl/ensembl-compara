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

### Dumps some basic information about the current release's species into a
### JSON file for use with selenium tests

use FindBin qw($Bin);
use JSON qw(to_json); 

BEGIN {
  unshift @INC, "$Bin/../../conf";
  unshift @INC, "$Bin/../../";
  require SiteDefs; SiteDefs->import;
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
}

use LoadPlugins;
use EnsEMBL::Web::SpeciesDefs;

my $sd = EnsEMBL::Web::SpeciesDefs->new;
my @valid_species = $sd->valid_species;

die "Couldn't get species list!" unless @valid_species;

my $config_file = sprintf('conf/release_%s_species.conf', $sd->ENSEMBL_VERSION);
open(CONF, '>', $config_file) or die "Couldn't open file $config_file for writing";

my $data = {};

foreach my $species (@valid_species) {
  my $info  = $sd->get_config($species, 'SAMPLE_DATA');
  my $dbs   = $sd->databases;
  if ($dbs->{'variation'}) {
    $info->{'variation_db'} = 1;
  }
  if ($dbs->{'funcgen'}) {
    $info->{'funcgen_db'} = 1;
  }
  $data->{$species} = $info;
}

print CONF to_json($data);

1;
