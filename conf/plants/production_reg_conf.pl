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
my $curr_eg_release = $curr_release - 53;
my $prev_eg_release = $curr_eg_release - 1;

# Species found on both vertebrates and non-vertebrates servers
my @overlap_species = qw(saccharomyces_cerevisiae drosophila_melanogaster caenorhabditis_elegans);

# ---------------------- CURRENT CORE DATABASES----------------------------------

# Use our mirror (which has all the databases)
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");

# Or use the official staging servers
#Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-3:4160/$curr_release");
# and remove the NV version of the shared species
#Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
#Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();
# before loading the V version
#Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-1:4519/$curr_release");

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease and LoadMembers only
# !!! COMMENT THIS SECTION OUT FOR ALL OTHER PIPELINES (for speed) !!!
#my $suffix_separator = '__cut_here__';
#Bio::EnsEMBL::Registry->load_registry_from_db(
#    -host   => 'mysql-ens-mirror-3',
#    -port   => 4275,
#    -user   => 'ensro',
#    -pass   => '',
#    -db_version     => $prev_release,
#    -species_suffix => $suffix_separator.$prev_release,
#);
# Never use EG's version of yeast & co
#Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species, $suffix_separator.$prev_release);
#Bio::EnsEMBL::Compara::Utils::Registry::remove_multi($suffix_separator.$prev_release);
#Bio::EnsEMBL::Registry->load_registry_from_db(
#    -host   => 'mysql-ens-mirror-1',
#    -port   => 4240,
#    -user   => 'ensro',
#    -pass   => '',
#    -db_version     => $prev_release,
#    -species_suffix => $suffix_separator.$prev_release,
#);
#------------------------COMPARA DATABASE LOCATIONS----------------------------------


my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-5', 'ensembl_compara_master_plants' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-5', "ensembl_compara_plants_${curr_eg_release}_${curr_release}" ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-5', "ensembl_compara_plants_${prev_eg_release}_${prev_release}" ],

    # homology dbs
    #'compara_members'  => [ 'mysql-ens-compara-prod-7', 'dthybert_plants_load_members_100'],
    #'compara_ptrees'   => [ '', '' ],
    'ptrees_prev'      => [ 'mysql-ens-compara-prod-3', 'cristig_default_plants_protein_trees_99' ],

    # LASTZ dbs
    'lastz_batch_1' => [ 'mysql-ens-compara-prod-6', 'muffato_plants_lastz_batch1d_100' ],
    'lastz_batch_2' => [ 'mysql-ens-compara-prod-1', 'muffato_plants_lastz_batch2d_100' ],
    #'lastz_batch_2c' => [ 'mysql-ens-compara-prod-3', 'muffato_plants_lastz_batch2c_100' ],
    
   # synteny
   # 'compara_syntenies' => [ 'mysql-ens-compara-prod-1', 'cristig_plants_synteny_99' ],

    # EPO dbs
    ## rice
    'rice_epo'         => [ 'mysql-ens-compara-prod-5', 'cristig_rice_epo_test5' ],
    #'rice_epo_prev'    => [ 'mysql-ens-compara-prod-5', 'cristig_rice_epo_test5' ],
    'rice_epo_low'     => [ 'mysql-ens-compara-prod-5', 'cristig_rice_epo_low_coverage_test' ],
    'rice_epo_anchors' => [ 'mysql-ens-compara-prod-5', 'cristig_generate_anchors_rice_99' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
        'ncbi_taxonomy' => [ 'mysql-ens-sta-1', "ncbi_taxonomy_$curr_release" ],
    });

# -------------------------------------------------------------------

1;
