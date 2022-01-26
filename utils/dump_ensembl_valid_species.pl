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
use FindBin qw($Bin);
use Data::Dumper;

BEGIN {
  unshift @INC, "$Bin/../conf";
  unshift @INC, "$Bin/../";
  require SiteDefs; SiteDefs->import;
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
}

use LoadPlugins;
use EnsEMBL::Web::SpeciesDefs;

my $sd = EnsEMBL::Web::SpeciesDefs->new;
my @sp_list = keys %{$sd->production_name_lookup()};
print join "\n", @sp_list;

1;
