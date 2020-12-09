#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
use Bio::EnsEMBL::Compara::Utils::Registry;

# ---------------------- CURRENT CORE DATABASES---------------------------------

# Benchmark dataset is e98 data : get it from the public server
# Bio::EnsEMBL::Registry->load_registry_from_url("mysql://anonymous\@ensembldb.ensembl.org/98");

#------------------------COMPARA DATABASE LOCATIONS----------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-10', 'carlac_benchmark_98_master' ],
    # 'compara_curr'   => [ 'mysql-ens-compara-prod-1', "ensembl_compara_$curr_release" ],

    # homology dbs
    'compara_members' => [ 'mysql-ens-compara-prod-6', 'carlac_default_vert_protein_trees_benchmark_98_100' ],
    'compara_ptrees'  => [ 'mysql-ens-compara-prod-2', 'carlac_default_vertebrates_protein_trees_102' ],

    # previous benchmarks
    'benchmark_98'  => [ 'mysql-ens-compara-prod-6', 'carlac_default_vert_protein_trees_benchmark_98' ],
    'benchmark_100' => [ 'mysql-ens-compara-prod-6', 'carlac_default_vert_protein_trees_benchmark_98_100' ],

};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );


1;
