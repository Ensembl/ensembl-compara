#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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
my $curr_eg_release = $curr_release - 53;
my $prev_eg_release = $curr_eg_release - 1;

# ---------------------- CURRENT CORE DATABASES---------------------------------

Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-compara-prod-8:4618/$curr_release");
Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();

#Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
#    -host   => 'mysql-ens-compara-prod-8',
#    -port   => 4618,
#    -user   => 'ensro',
#    -pass   => '',
#    -dbname => "fungi_ascomycota2_collection_core_${curr_eg_release}_${curr_release}_1",
#);

Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
    -host   => 'mysql-ens-compara-prod-8',
    -port   => 4618,
    -user   => 'ensro',
    -pass   => '',
    -dbname => "protists_choanoflagellida1_collection_core_${curr_eg_release}_${curr_release}_1",
);
Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
    -host   => 'mysql-ens-compara-prod-8',
    -port   => 4618,
    -user   => 'ensro',
    -pass   => '',
    -dbname => "protists_ichthyosporea1_collection_core_${curr_eg_release}_${curr_release}_1",
);

#------------------------COMPARA DATABASE LOCATIONS----------------------------------
my $homology_reference_host = $ENV{'homology_reference_host'} || 'mysql-ens-compara-prod-8';

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    'compara_references' => [ $homology_reference_host, 'ensembl_compara_references_beta7' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-compara-prod-8', "ncbi_taxonomy" ],
});

# -------------------------------------------------------------------

1;
