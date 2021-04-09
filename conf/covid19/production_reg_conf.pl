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


# Release Coordinator, please update this file before starting every release
# and check the changes back into GIT for everyone's benefit.

# Things that normally need updating are:
#
# 1. Release number
# 2. Check the name prefix of all databases
# 3. Possibly add entries for core databases that are still on genebuilders' servers

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::Registry;

my $curr_release = $ENV{'CURR_ENSEMBL_RELEASE'};
my $prev_release = $curr_release - 1;

# ---------------------- CURRENT CORE DATABASES---------------------------------

# main sars-cov-2 core - with canonical data
my $core_dbs = {
    # 'sarsc2_gca009858895_3' => [ 'mysql-ens-genebuild-prod-1', 'sarsc2_gca009858895_3_core_101_3_canon' ],
    # 'sars_cov_2' => [ 'mysql-ens-genebuild-prod-2', 'sars_cov_2_core_100' ],
    'sars_cov_2' => [ 'mysql-ens-sta-5', 'sars_cov_2_core_102_1' ],
};
Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $core_dbs );

# Add collection cores
Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
    -host   => 'mysql-ens-microbes-prod-3',
    -port   => 4207,
    -user   => 'ensro',
    -pass   => '',
    -dbname => 'virus_mixed_collection_core_48_101_1',
);

Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
    -host   => 'mysql-ens-microbes-prod-3',
    -port   => 4207,
    -user   => 'ensro',
    -pass   => '',
    -dbname => 'virus_orthocoronavirinae_collection_core_48_101_1',
);
#------------------------COMPARA DATABASE LOCATIONS----------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-9', 'carlac_ensembl_compara_covid19_master' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-9', 'ensembl_compara_covid19_103' ],

    'compara_members_test16' => [ 'mysql-ens-compara-prod-6', 'carlac_test16_covid19_load_members_101' ],
    'compara_ptrees_test16'  => [ 'mysql-ens-compara-prod-6', 'carlac_test16_covid19_protein_trees_101' ],

    'compara_members' => [ 'mysql-ens-compara-prod-6', 'carlac_covid19_load_members_101' ],
    'compara_ptrees'  => [ 'mysql-ens-compara-prod-6', 'carlac_default_covid19_protein_trees_103' ],

    'register_hal' => [ 'mysql-ens-compara-prod-9', 'thiagogenez_covid19_register_halfile_102' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-mirror-1', "ncbi_taxonomy_$curr_release" ],
});

# -------------------------------------------------------------------

1;
