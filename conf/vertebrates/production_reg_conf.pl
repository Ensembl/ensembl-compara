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

# ---------------------- CURRENT CORE DATABASES---------------------------------

# All the core databases live on the Vertebrates staging server or our mirror
#Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-1.ebi.ac.uk:4519/$curr_release");
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");

# Add in extra cores from genebuild server
# my $extra_core_dbs = {
#     'cyprinus_carpio_german_mirror' => [ 'mysql-ens-vertannot-staging', "cyprinus_carpio_germanmirror_core_99_10" ],
#     'cyprinus_carpio_hebao_red' => [ 'mysql-ens-vertannot-staging', "cyprinus_carpio_hebaored_core_99_10" ],
# };
#
# Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $extra_core_dbs );

# Ensure we're using the correct cores for species that overlap with metazoa
my @metazoa_overlap_species = qw(drosophila_melanogaster caenorhabditis_elegans);
Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@metazoa_overlap_species);
my $metazoa_overlap_cores = {
    'drosophila_melanogaster' => [ 'mysql-ens-vertannot-staging', "drosophila_melanogaster_core_" . $curr_release . "_9" ],
    'caenorhabditis_elegans'  => [ 'mysql-ens-vertannot-staging', "caenorhabditis_elegans_core_" . $curr_release . "_269" ],
};
Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $metazoa_overlap_cores );

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease, LoadMembers and MercatorPecan
*Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-sta-1',
        -port   => 4519,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
};

#------------------------COMPARA DATABASE LOCATIONS----------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-1', 'ensembl_compara_master' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-1', "ensembl_compara_$curr_release" ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-1', "ensembl_compara_$prev_release" ],

    # release replicates - to speed up dumping
    # 'compara_curr_2'   => [ 'mysql-ens-compara-prod-2', "ensembl_compara_$curr_release" ],
    # 'compara_curr_3'   => [ 'mysql-ens-compara-prod-3', "ensembl_compara_$curr_release" ],

    # homology dbs
    #'compara_members'         => [ 'mysql-ens-compara-prod-1',  '' ],
    #'compara_ptrees'          => [ 'mysql-ens-compara-prod-X',  '' ],
    #'compara_nctrees'         => [ 'mysql-ens-compara-prod-X',  '' ],
    #'murinae_ptrees'          => [ 'mysql-ens-compara-prod-X',  '' ],
    #'murinae_nctrees'         => [ 'mysql-ens-compara-prod-X',  '' ],
    'murinae_ptrees_prev'     => [ 'mysql-ens-compara-prod-2',  'carlac_vertebrates_murinae_protein_reindexed_trees_104' ],
    'murinae_nctrees_prev'    => [ 'mysql-ens-compara-prod-2',  'carlac_vertebrates_murinae_ncrna_reindexed_trees_104' ],
    #'pig_breeds_ptrees'       => [ 'mysql-ens-compara-prod-X',  '' ],
    #'pig_breeds_nctrees'      => [ 'mysql-ens-compara-prod-X',  '' ],
    'pig_breeds_ptrees_prev'  => [ 'mysql-ens-compara-prod-3',  'carlac_vertebrates_pig_breeds_protein_reindexed_trees_104' ],
    'pig_breeds_nctrees_prev' => [ 'mysql-ens-compara-prod-3',  'carlac_vertebrates_pig_breeds_ncrna_reindexed_trees_104' ],

    # LASTZ dbs
    #'lastz_batch_1'    => [ 'mysql-ens-compara-prod-X', '' ],
    'unidir_lastz'     => [ 'mysql-ens-compara-prod-1', 'ensembl_vertebrates_unidirectional_lastz' ],

    # EPO dbs
    ## mammals
    #'mammals_epo_w_ext'    => [ 'mysql-ens-compara-prod-X', '' ],
    'mammals_epo_prev'     => [ 'mysql-ens-compara-prod-4', 'jalvarez_mammals_epo_with2x_103' ],
    'mammals_epo_anchors'  => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    ## sauropsids
    'sauropsids_epo_w_ext'   => [ 'mysql-ens-compara-prod-4', 'carlac_sauropsids_epo_with_ext_104' ],
    'sauropsids_epo_prev'    => [ 'mysql-ens-compara-prod-4', 'carlac_sauropsids_epo_with_ext_104' ],
    'sauropsids_epo_anchors' => [ 'mysql-ens-compara-prod-1', 'mm14_4saur_gen_anchors_hacked_86' ],

    ## fish
    'fish_epo_w_ext'    => [ 'mysql-ens-compara-prod-3', 'carlac_fish_epo_update_104' ],
    'fish_epo_prev'     => [ 'mysql-ens-compara-prod-3', 'carlac_fish_epo_update_104' ],
    'fish_epo_anchors'  => [ 'mysql-ens-compara-prod-8', 'muffato_generate_anchors_fish_100' ],

    ## primates
    #'primates_epo_w_ext'    => [ 'mysql-ens-compara-prod-X', '' ],
    #'primates_epo_prev'     => [ 'mysql-ens-compara-prod-X', '' ],  # Primates are reused from mammals of the *same release* (same anchors and subset of species)
    'primates_epo_anchors'  => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    ## pig strains
    #'pig_breeds_epo_w_ext'     => [ 'mysql-ens-compara-prod-X', '' ],
    #'pig_breeds_epo_prev'      => [ 'mysql-ens-compara-prod-X', '' ],  # Pig breeds are reused from mammals of the *same release* (same anchors and subset of species)
    'pig_breeds_epo_anchors'   => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    ## murinae
    #'murinae_epo'          => [ 'mysql-ens-compara-prod-X', '' ],
    'murinae_epo_prev'     => [ 'mysql-ens-compara-prod-4', 'jalvarez_murinae_epo_103' ],
    'murinae_epo_anchors'  => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    # other alignments
    #'amniotes_pecan'      => [ 'mysql-ens-compara-prod-X', '' ],
    'amniotes_pecan_prev' => [ 'mysql-ens-compara-prod-3', 'carlac_amniotes_pecan_update_104' ],

    #'compara_syntenies'   => [ 'mysql-ens-compara-prod-X', '' ],

    # miscellaneous
    #'alt_allele_projection' => [ 'mysql-ens-compara-prod-X', '' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

my $ancestral_dbs = {
    'ancestral_prev' => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$prev_release" ],
    'ancestral_curr' => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$curr_release" ],

    #'mammals_ancestral'    => [ 'mysql-ens-compara-prod-X', '' ],
    #'primates_ancestral'   => [ 'mysql-ens-compara-prod-X', '' ],
    'sauropsids_ancestral' => [ 'mysql-ens-compara-prod-4', 'carlac_sauropsids_ancestral_core_104' ],
    'fish_ancestral'       => [ 'mysql-ens-compara-prod-3', 'carlac_fish_ancestral_core_104' ],
    #'murinae_ancestral'    => [ 'mysql-ens-compara-prod-X', '' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $ancestral_dbs );

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-1-b', "ncbi_taxonomy_$curr_release" ],
});

# -------------------------------------------------------------------

1;
