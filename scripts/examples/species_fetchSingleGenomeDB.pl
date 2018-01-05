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
# This script queries the Compara and the Core databases to fetch 
# information about the human genome
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $genomedb_adaptor = $reg->get_adaptor('Multi', 'compara', 'GenomeDB');

# get GenomeDB for human
my $humanGDB = $genomedb_adaptor->fetch_by_registry_name("human");

# get DBAdaptor for Human ensembl core database
my $human_core_DBA = $humanGDB->db_adaptor;

# print some info
printf("COMPARA %s : %s : %s\n   %s\n", $humanGDB->name, $humanGDB->assembly, $humanGDB->genebuild, 
    join("_", reverse($humanGDB->taxon->classification)));

my $species_name = $human_core_DBA->get_MetaContainer->get_scientific_name;
my $species_assembly = $human_core_DBA->get_CoordSystemAdaptor->fetch_all->[0]->version;
my $species_genebuild = $human_core_DBA->get_MetaContainer->get_genebuild;
printf("CORE    %s : %s : %s\n", $species_name, $species_assembly, $species_genebuild);

