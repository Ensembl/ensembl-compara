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

# ---------------------- CURRENT CORE DATABASES----------------------------------

Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-1-b:4519/$curr_release");
# But remove the non-vertebrates species
Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();
# Non-Vertebrates server
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-3-b:4160/$curr_release");
# Bacteria server: all species used in Pan happen to be in this database
Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
    -host   => 'mysql-ens-sta-4-b',
    -port   => 4494,
    -user   => 'ensro',
    -pass   => '',
    -dbname => "bacteria_0_collection_core_${curr_eg_release}_${curr_release}_1",
);

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease and LoadMembers only
# *Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
#     Bio::EnsEMBL::Registry->load_registry_from_db(
#         -host   => 'mysql-ens-sta-1',
#         -port   => 4519,
#         -user   => 'ensro',
#         -pass   => '',
#         -db_version     => $prev_release,
#         -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
#     );
#     Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
#     Bio::EnsEMBL::Compara::Utils::Registry::remove_multi(undef, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
#     Bio::EnsEMBL::Registry->load_registry_from_db(
#         -host   => 'mysql-ens-general-prod-3',
#         -port   => 4631,
#         -user   => 'ensro',
#         -pass   => '',
#         -db_version     => $prev_release,
#         -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
#     );
#     # Bacteria server: all species used in Pan happen to be in this database
#     Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
#         -host   => 'mysql-ens-general-prod-4',
#         -port   => 4632,
#         -user   => 'ensro',
#         -pass   => '',
#         -dbname => "bacteria_0_collection_core_${prev_eg_release}_${prev_release}_1",
#         -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
#     );
# };

#------------------------COMPARA DATABASE LOCATIONS----------------------------------


my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-7', 'ensembl_compara_master_pan' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-7', "ensembl_compara_pan_homology_${curr_eg_release}_${curr_release}" ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-7', "ensembl_compara_pan_homology_${prev_eg_release}_${prev_release}" ],

    # homology dbs
    'compara_members'  => [ 'mysql-ens-compara-prod-10', 'cristig_pan_load_members_103' ],
    'compara_ptrees'   => [ 'mysql-ens-compara-prod-7', 'cristig_default_pan_protein_trees_103' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-4-b', "ncbi_taxonomy_${curr_release}" ],
});

# -------------------------------------------------------------------

1;
