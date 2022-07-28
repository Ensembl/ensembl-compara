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

# Species found on both vertebrates and non-vertebrates servers
my @overlap_species = qw(caenorhabditis_elegans drosophila_melanogaster saccharomyces_cerevisiae);

# ---------------------- CURRENT CORE DATABASES---------------------------------

# Load RR server first for priority
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-5:4684/$curr_release");
Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();
# Use the mirror servers
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-mirror-1:4240/$curr_release");
# but remove the Vertebrates version of the shared species
Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();
# before loading all Non-Vertebrates
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-mirror-3:4275/$curr_release");

# Used for protist collection databases
Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
    -host   => 'mysql-ens-sta-3',
    -port   => 4160,
    -user   => 'ensro',
    -pass   => '',
    -dbname => "protists_choanoflagellida1_collection_core_${curr_eg_release}_${curr_release}_1",
);
Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
    -host   => 'mysql-ens-sta-3',
    -port   => 4160,
    -user   => 'ensro',
    -pass   => '',
    -dbname => "protists_ichthyosporea1_collection_core_${curr_eg_release}_${curr_release}_1",
);

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease, LoadMembers and MercatorPecan
*Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-mirror-1',
        -port   => 4240,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
    Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
    Bio::EnsEMBL::Compara::Utils::Registry::remove_multi(undef, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-mirror-3',
        -port   => 4275,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
};

#------------------------COMPARA DATABASE LOCATIONS----------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    'compara_references' => [ 'mysql-ens-compara-prod-2', 'ensembl_compara_references' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-mirror-1', "ncbi_taxonomy_$curr_release" ],
});

# -------------------------------------------------------------------

1;
