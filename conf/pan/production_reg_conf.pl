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
my $curr_eg_release = $ENV{'CURR_EG_RELEASE'};
my $prev_eg_release = $curr_eg_release - 1;

# Species found on both vertebrates and non-vertebrates servers
my @overlap_species = qw(saccharomyces_cerevisiae drosophila_melanogaster caenorhabditis_elegans);
Bio::EnsEMBL::Compara::Utils::Registry::suppress_overlap_species_warnings(\@overlap_species);

# ---------------------- DATABASE HOSTS -----------------------------------------

my ($curr_vert_host, $curr_vert_port, $curr_nv_host, $curr_nv_port);
if ($curr_release % 2 == 0) {
    ($curr_vert_host, $curr_vert_port) = ('mysql-ens-sta-1', 4519);
    ($curr_nv_host, $curr_nv_port)     = ('mysql-ens-sta-3', 4160);
} else {
    ($curr_vert_host, $curr_vert_port) = ('mysql-ens-sta-1-b', 4685);
    ($curr_nv_host, $curr_nv_port)     = ('mysql-ens-sta-3-b', 4686);
}

my ($prev_vert_host, $prev_vert_port, $prev_nv_host, $prev_nv_port);
if ($prev_release % 2 == 0) {
    ($prev_vert_host, $prev_vert_port) = ('mysql-ens-sta-1', 4519);
    ($prev_nv_host, $prev_nv_port)     = ('mysql-ens-sta-3', 4160);
} else {
    ($prev_vert_host, $prev_vert_port) = ('mysql-ens-sta-1-b', 4685);
    ($prev_nv_host, $prev_nv_port)     = ('mysql-ens-sta-3-b', 4686);
}

# ---------------------- CURRENT CORE DATABASES----------------------------------

Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");

# Ensure we are using the correct cores for species that overlap with vertebrates
Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
my $overlap_cores = {
    'caenorhabditis_elegans'   => [ 'mysql-ens-vertannot-staging', "caenorhabditis_elegans_core_${curr_eg_release}_${curr_release}_282" ],
    'drosophila_melanogaster'  => [ 'mysql-ens-vertannot-staging', "drosophila_melanogaster_core_${curr_eg_release}_${curr_release}_11" ],
    'saccharomyces_cerevisiae' => [ 'mysql-ens-vertannot-staging', "saccharomyces_cerevisiae_core_${curr_eg_release}_${curr_release}_4" ],
};
Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $overlap_cores );

# Bacteria: all species used in Pan happen to be in this database
Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
    -host   => 'mysql-ens-sta-4',
    -port   => 4494,
    -user   => 'ensro',
    -pass   => '',
    -dbname => "bacteria_0_collection_core_${curr_eg_release}_${curr_release}_1",
);

# ---------------------- CURRENT CORE DATABASES : ALTERNATE HOSTS ----------------

# Vertebrates server
#Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@$curr_vert_host:$curr_vert_port/$curr_release");
# But remove the non-vertebrates species
#Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
#Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();
# Non-Vertebrates server
#Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@$curr_nv_host:$curr_nv_port/$curr_release");
# Bacteria server is not alternated between releases
#Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
#    -host   => 'mysql-ens-sta-4',
#    -port   => 4494,
#    -user   => 'ensro',
#    -pass   => '',
#    -dbname => "bacteria_0_collection_core_${curr_eg_release}_${curr_release}_1",
#);

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease and LoadMembers only
*Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => $prev_vert_host,
        -port   => $prev_vert_port,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
    Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
    Bio::EnsEMBL::Compara::Utils::Registry::remove_multi(undef, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => $prev_nv_host,
        -port   => $prev_nv_port,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
    # Bacteria server: all species used in Pan happen to be in this database
    Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
        -host   => 'mysql-ens-mirror-4',
        -port   => 4495,
        -user   => 'ensro',
        -pass   => '',
        -dbname => "bacteria_0_collection_core_${prev_eg_release}_${prev_release}_1",
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
};

#------------------------COMPARA DATABASE LOCATIONS----------------------------------


my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-7', 'ensembl_compara_master_pan' ],
    #'compara_curr'   => [ 'mysql-ens-compara-prod-7', "ensembl_compara_pan_homology_${curr_eg_release}_${curr_release}" ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-7', "ensembl_compara_pan_homology_${prev_eg_release}_${prev_release}" ],

    # homology dbs
    #'compara_members'  => [ 'mysql-ens-compara-prod-X', '' ],
    #'compara_ptrees'   => [ 'mysql-ens-compara-prod-x', ''],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-4', "ncbi_taxonomy_${curr_release}" ],
});

# -------------------------------------------------------------------

1;

