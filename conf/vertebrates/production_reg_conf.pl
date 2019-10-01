#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

# The majority of core databases live on staging servers:
#Bio::EnsEMBL::Registry->load_registry_from_url(
#   "mysql://ensro\@mysql-ens-sta-1.ebi.ac.uk:4519/$curr_release");
Bio::EnsEMBL::Registry->load_registry_from_url(
    "mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");

# Add in extra cores from genebuild server
# my $extra_core_dbs = {
#     'cyprinus_carpio_german_mirror' => [ 'mysql-ens-vertannot-staging', "cyprinus_carpio_germanmirror_core_99_10" ],
#     'cyprinus_carpio_hebao_red' => [ 'mysql-ens-vertannot-staging', "cyprinus_carpio_hebaored_core_99_10" ],
# };
#
# Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $extra_core_dbs );

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will ONLY be required by:
#   * PrepareMasterDatabaseForRelease_conf
#   * LoadMembers_conf
#   * MercatorPecan_conf
# !!! COMMENT THIS SECTION OUT FOR ALL OTHER PIPELINES (for speed) !!!

my $suffix_separator = '__cut_here__';
Bio::EnsEMBL::Registry->load_registry_from_db(
   -host           => 'mysql-ens-mirror-1',
   -port           => 4240,
   -user           => 'ensro',
   -pass           => '',
   -db_version     => $prev_release,
   -species_suffix => $suffix_separator.$prev_release,
);

#------------------------COMPARA DATABASE LOCATIONS----------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-1', 'ensembl_compara_master' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-1', "ensembl_compara_$curr_release" ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-1', "ensembl_compara_$prev_release" ],

    # homology dbs
    'compara_members'       => [ 'mysql-ens-compara-prod-8', 'jalvarez_vertebrates_load_members_99' ],
    # 'compara_ptrees'        => [ 'mysql-ens-compara-prod-', '' ],
    'ptrees_prev'           => [ 'mysql-ens-compara-prod-2', 'mateus_default_vertebrates_protein_trees_98' ],
    # 'compara_families'      => [ 'mysql-ens-compara-prod-', '' ],
    # 'compara_nctrees'       => [ 'mysql-ens-compara-prod-', '' ],
    'nctrees_prev'          => [ 'mysql-ens-compara-prod-7', 'muffato_default_vertebrates_ncrna_trees_98' ],
    # 'murinae_ptrees'        => [ 'mysql-ens-compara-prod-', '' ],
    # 'murinae_nctrees'       => [ 'mysql-ens-compara-prod-', '' ],
    'murinae_ptrees_prev'   => [ 'mysql-ens-compara-prod-7', 'muffato_murinae_protein_reindexed_trees_98' ],
    'murinae_nctrees_prev'  => [ 'mysql-ens-compara-prod-7', 'muffato_murinae_ncrna_reindexed_trees_98' ],
    # 'sus_ptrees'            => [ 'mysql-ens-compara-prod-', '' ],
    # 'sus_nctrees'           => [ 'mysql-ens-compara-prod-', '' ],
    'sus_ptrees_prev'       => [ 'mysql-ens-compara-prod-1', 'carlac_sus_vertebrates_protein_trees_98' ],
    'sus_nctrees_prev'      => [ 'mysql-ens-compara-prod-5', 'muffato_sus_vertebrates_ncrna_trees_98' ],

    # LASTZ dbs
    'lastz_batch_1'    => [ 'mysql-ens-compara-prod-3', 'carlac_vertebrates_lastz_batch_1_99' ],
    'lastz_batch_2'    => [ 'mysql-ens-compara-prod-6', 'jalvarez_vertebrates_lastz_batch2_99' ],
    'lastz_batch_3'    => [ 'mysql-ens-compara-prod-2', 'carlac_vertebrates_lastz_batch3_99' ],
    # 'lastz_batch_4'    => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_5'    => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_6'    => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_7'    => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_8'    => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_9'    => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_10'   => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_11'   => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_12'   => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_13'   => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_14'   => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_15'   => [ 'mysql-ens-compara-prod-', '' ],

    # EPO dbs
    ## mammals
    # 'mammals_epo'         => [ 'mysql-ens-compara-prod-', '' ],
    'mammals_epo_prev'    => [ 'mysql-ens-compara-prod-2', 'mateus_mammals_epo_98' ],
    'mammals_epo_low'     => [ 'mysql-ens-compara-prod-8', 'mateus_mammals_epo_low_coverage_98' ],
    'mammals_epo_anchors' => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    ## sauropsids
    #'sauropsids_epo'         => [ 'mysql-ens-compara-prod-4', 'carlac_sauropsids_epo_96' ],
    #'sauropsids_epo_prev'    => [ 'mysql-ens-compara-prod-1', 'muffato_sauropsids_epo_95' ],
    #'sauropsids_epo_low'     => [ 'mysql-ens-compara-prod-4', 'carlac_sauropsids_epo_low_coverage_96' ],
    #'sauropsids_epo_anchors' => [ 'mysql-ens-compara-prod-1', 'mm14_4saur_gen_anchors_hacked_86' ],

    ## fish
    # 'fish_epo'         => [ 'mysql-ens-compara-prod-', '' ],
    'fish_epo_prev'    => [ 'mysql-ens-compara-prod-1', 'carlac_fish_epo_98' ],
    'fish_epo_low'     => [ 'mysql-ens-compara-prod-1', 'carlac_fish_epo_low_coverage_98' ],
    'fish_epo_anchors' => [ 'mysql-ens-compara-prod-5', 'muffato_generate_anchors_fish_96' ],

    ## primates
    # 'primates_epo'         => [ 'mysql-ens-compara-prod-', '' ],
    'primates_epo_prev'    => [ 'mysql-ens-compara-prod-3', 'mateus_primates_epo_98' ],      # Primates are reused from mammals of the *same release* (same anchors and subset of species)
    'primates_epo_low'     => [ 'mysql-ens-compara-prod-6', 'mateus_primates_epo_low_coverage_98' ],
    'primates_epo_anchors' => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    # other alignments
    # 'amniotes_pecan'      => [ 'mysql-ens-compara-prod-', '' ],
    'amniotes_pecan_prev' => [ 'mysql-ens-compara-prod-4', 'carlac_amniotes_mercator_pecan_98' ],

    # 'compara_syntenies'   => [ 'mysql-ens-compara-prod-', '' ],

    # miscellaneous
    # 'alt_allele_projection' => [ 'mysql-ens-compara-prod-', '' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

my $ancestral_dbs = {
    'ancestral_prev'    => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$prev_release" ],
    'ancestral_curr'    => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$curr_release" ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $ancestral_dbs );

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
        'ncbi_taxonomy' => [ 'mysql-ens-sta-1', 'ncbi_taxonomy' ],
    });

# -------------------------------------------------------------------

1;
