#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script queries the Compara database to fetch all the MethodLinkSpeciesSet
# objects used by orthologies
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $mlss_adaptor = $reg->get_adaptor('Multi', 'compara', 'MethodLinkSpeciesSet');
my $mlss_list = $mlss_adaptor->fetch_all_by_method_link_type('ENSEMBL_ORTHOLOGUES');

foreach my $mlss (@{$mlss_list}) {
  my $species_names = '';
  foreach my $gdb (@{$mlss->species_set->genome_dbs}) {
    $species_names .= $gdb->dbID.".".$gdb->name."  ";
  }
  printf("mlss(%d) %s : %s\n", $mlss->dbID, $mlss->method->type, $species_names);
}

