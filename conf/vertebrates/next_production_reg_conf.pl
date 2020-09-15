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

my $next_release = $ENV{'CURR_ENSEMBL_RELEASE'};
my $curr_release = $next_release - 1;
my $prev_release = $curr_release - 1;

my $prev_db_suffix = Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX;

# ---------------------- SPECIES TO UPDATE OUT OF THE RELEASE ------------------

my $updated_core_dbs = {
    'mus_musculus' => [ 'mysql-ens-genebuild-prod-2', 'thibaut_mus_musculus_havana_39' ],
};

my $prev_core_dbs = {
    "mus_musculus$prev_db_suffix" => [ 'mysql-ens-vertannot-staging', 'mus_musculus_core_102_38' ],
};

# ---------------------- CURRENT CORE DATABASES --------------------------------

# All the core databases live on the Vertebrates staging server or our mirror
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-1:4519/$curr_release");
# Remove species that will be updated $next_release and the ancestral sequences core database
Bio::EnsEMBL::Compara::Utils::Registry::remove_species( [ keys %$updated_core_dbs ] );
Bio::EnsEMBL::Compara::Utils::Registry::remove_species( [ 'ancestral_sequences' ] );
# Add the correct core database for those species
Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $updated_core_dbs );

# ---------------------- PREVIOUS CORE DATABASES -------------------------------

# Previous release core databases will be required by PrepareMasterDatabaseForRelease, LoadMembers and Mercator-Pecan
*Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-mirror-1',
        -port   => 4240,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => $prev_db_suffix,
    );
    # Do the same with the previous core database
    Bio::EnsEMBL::Compara::Utils::Registry::remove_species( [ keys %$prev_core_dbs ] );
    Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $prev_core_dbs );
};

# ---------------------- COMPARA DATABASE LOCATIONS ----------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-1', 'ensembl_compara_master' ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-1', "ensembl_compara_$curr_release" ],

    # homology dbs
    'compara_members'         => [ 'mysql-ens-compara-prod-4', 'jalvarez_vertebrates_load_members_103' ],
    'compara_members_prev'    => [ 'mysql-ens-compara-prod-10', 'jalvarez_vertebrates_load_members_102' ],
    # 'murinae_ptrees'          => [ 'mysql-ens-compara-prod-',  '' ],
    # 'murinae_nctrees'         => [ 'mysql-ens-compara-prod-',  '' ],
    'murinae_ptrees_prev'     => [ 'mysql-ens-compara-prod-7',  'jalvarez_vertebrates_murinae_protein_reindexed_trees_102' ],
    'murinae_nctrees_prev'    => [ 'mysql-ens-compara-prod-8',  'jalvarez_vertebrates_murinae_ncrna_reindexed_trees_102' ],

    # LASTZ dbs
    'lastz_batch_1'    => [ 'mysql-ens-compara-prod-8', 'jalvarez_vertebrates_lastz_batch1_103' ],
    # 'lastz_batch_2'    => [ 'mysql-ens-compara-prod-', '_vertebrates_lastz_batch2_103' ],
    # 'lastz_batch_3'    => [ 'mysql-ens-compara-prod-', '_vertebrates_lastz_batch3_103' ],
    # 'lastz_batch_4'    => [ 'mysql-ens-compara-prod-', '_vertebrates_lastz_batch4_103' ],

    # EPO dbs
    ## mammals
    # 'mammals_epo_high_low'=> [ 'mysql-ens-compara-prod-', '' ],
    'mammals_epo_prev'    => [ 'mysql-ens-compara-prod-8', 'muffato_mammals_epo_with2x_101' ],
    'mammals_epo_anchors' => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    # other alignments
    # 'amniotes_pecan'      => [ 'mysql-ens-compara-prod-', '' ],
    'amniotes_pecan_prev' => [ 'mysql-ens-compara-prod-3', 'dthybert_amniotes_mercator_pecan_101' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ---------------------- NON-COMPARA DATABASES ---------------------------------

my $ancestral_dbs = {
    'ancestral_prev' => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$curr_release" ],
    'ancestral_curr' => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$next_release" ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $ancestral_dbs );

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-1', "ncbi_taxonomy_$curr_release" ],
});

# ------------------------------------------------------------------------------

1;
