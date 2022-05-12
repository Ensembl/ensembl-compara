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
# 4. For fungi & protists, check the collection database names as they change

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::Registry;


my $curr_release = $ENV{'CURR_ENSEMBL_RELEASE'};
my $prev_release = $curr_release - 1;
my $curr_eg_release = $ENV{'CURR_EG_RELEASE'};
my $prev_eg_release = $curr_eg_release - 1;

# my @dbnames_current = (
# "fungi_ascomycota1_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_ascomycota2_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_ascomycota3_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_ascomycota4_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_ascomycota5_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_basidiomycota1_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_basidiomycota2_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_blastocladiomycota1_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_chytridiomycota1_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_entomophthoromycota1_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_microsporidia1_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_mucoromycota1_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_neocallimastigomycota1_collection_core_${curr_eg_release}_${curr_release}_1",
# "fungi_rozellomycota1_collection_core_${curr_eg_release}_${curr_release}_1"
# );

# my @dbnames_previous = (
# "fungi_ascomycota1_collection_core_${prev_eg_release}_${prev_release}_1",
# "fungi_ascomycota2_collection_core_${prev_eg_release}_${prev_release}_1",
# "fungi_ascomycota3_collection_core_${prev_eg_release}_${prev_release}_1",
# "fungi_ascomycota4_collection_core_${prev_eg_release}_${prev_release}_1",
# "fungi_basidiomycota1_collection_core_${prev_eg_release}_${prev_release}_1",
# "fungi_blastocladiomycota1_collection_core_${prev_eg_release}_${prev_release}_1",
# "fungi_chytridiomycota1_collection_core_${prev_eg_release}_${prev_release}_1",
# "fungi_entomophthoromycota1_collection_core_${prev_eg_release}_${prev_release}_1",
# "fungi_microsporidia1_collection_core_${prev_eg_release}_${prev_release}_1",
# "fungi_mucoromycota1_collection_core_${prev_eg_release}_${prev_release}_1",
# "fungi_neocallimastigomycota1_collection_core_${prev_eg_release}_${prev_release}_1",
# "fungi_rozellomycota1_collection_core_${prev_eg_release}_${prev_release}_1"
# );

# ---------------------- CURRENT CORE DATABASES----------------------------------

# Server for single species fungal cores
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-3-b:4686/$curr_release");
Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();

# Fungi collection databases for current cores if any - if none, can remove
# for my $dbname (@dbnames_current) {
#     Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
#         -host   => 'mysql-ens-sta-3-b',
#         -port   => 4686,
#         -user   => 'ensro',
#         -pass   => '',
#         -dbname => $dbname,
#     );
# }


# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease and LoadMembers only
*Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-sta-3',
        -port   => 4160,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
    Bio::EnsEMBL::Compara::Utils::Registry::remove_multi(undef, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);

    # Fungi collection databases
    # for my $dbname (@dbnames_previous) {
    #     Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
    #         -host   => 'mysql-ens-sta-3',
    #         -port   => 4160,
    #         -user   => 'ensro',
    #         -pass   => '',
    #         -dbname => $dbname,
    #         -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    #     );
    # }
};

#------------------------COMPARA DATABASE LOCATIONS----------------------------------

my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-microbes-prod-3', 'ensembl_compara_master_fungi' ], # Edit for server and correct db name
    'compara_curr'   => [ 'mysql-ens-microbes-prod-3', "ensembl_compara_fungi_${curr_eg_release}_${curr_release}" ],
    'compara_prev'   => [ 'mysql-ens-sta-3', "ensembl_compara_fungi_${prev_eg_release}_${prev_release}" ],

    # homology dbs
    'compara_members'  => [ 'mysql-ens-microbes-prod-3', 'fungi_load_members_105' ],
    'compara_ptrees'   => [ 'mysql-ens-microbes-prod-3', 'fungi_protein_trees_105' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-3-b', "ncbi_taxonomy_${curr_release}" ],
});

# -------------------------------------------------------------------

1;
