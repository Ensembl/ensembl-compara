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

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::Registry;

my $curr_release = $ENV{'CURR_ENSEMBL_RELEASE'};
my $prev_release = $curr_release - 1;
my $curr_eg_release = $ENV{'CURR_EG_RELEASE'};
my $prev_eg_release = $curr_eg_release - 1;

# ---------------------------- CORE DATABASES ----------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $core_dbs = {}; # TAG: <core_dbs_hash>

Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $core_dbs );

# --------------------------- COMPARA DATABASES --------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ '', '' ], # TAG: <master_db_info>
    # 'compara_curr'   => [ 'mysql-ens-compara-prod-1', "ensembl_compara_$curr_release" ],
    # 'compara_prev'   => [ 'mysql-ens-compara-prod-1', "ensembl_compara_$prev_release" ],

    # homology dbs
    # 'compara_members'       => [ 'mysql-ens-compara-prod-2', 'carlac_vertebrates_load_members_97' ],
    # 'compara_ptrees'        => [ 'mysql-ens-compara-prod-1', 'carlac_default_vertebrates_protein_trees_97' ],
    # 'compara_families'      => [ 'mysql-ens-compara-prod-7', 'muffato_ensembl_families_97' ],
    # 'compara_nctrees'       => [ 'mysql-ens-compara-prod-6', 'muffato_default_vertebrates_ncrna_trees_97' ],

    # LASTZ dbs
    # 'lastz_batch_1'    => [ 'mysql-ens-compara-prod-3', 'carlac_vertebrates_lastz_batch1' ],
    # 'lastz_batch_2'    => [ 'mysql-ens-compara-prod-6', 'mateus_vertebrates_lastz_batch2' ],
    # 'lastz_batch_3'    => [ 'mysql-ens-compara-prod-7', 'muffato_vertebrates_lastz_batch3_97' ],

    # EPO dbs
    ## mammals
    # 'mammals_epo'         => [ 'mysql-ens-compara-prod-4', 'carlac_mammals_epo_97' ],
    # 'mammals_epo_prev'    => [ 'mysql-ens-compara-prod-2', 'mateus_mammals_epo_96' ],
    # 'mammals_epo_low'     => [ 'mysql-ens-compara-prod-4', 'carlac_mammals_epo_low_coverage_97' ],
    # 'mammals_epo_anchors' => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    ## sauropsids
    # 'sauropsids_epo'         => [ 'mysql-ens-compara-prod-4', 'carlac_sauropsids_epo_96' ],
    # 'sauropsids_epo_prev'    => [ 'mysql-ens-compara-prod-1', 'muffato_sauropsids_epo_95' ],
    # 'sauropsids_epo_low'     => [ 'mysql-ens-compara-prod-4', 'carlac_sauropsids_epo_low_coverage_96' ],
    # 'sauropsids_epo_anchors' => [ 'mysql-ens-compara-prod-1', 'mm14_4saur_gen_anchors_hacked_86' ],

    ## fish
    # 'fish_epo'         => [ 'mysql-ens-compara-prod-3', 'muffato_fish_epo_96' ],
    # 'fish_epo_prev'    => [ 'mysql-ens-compara-prod-3', 'muffato_fish_epo_96' ],
    # 'fish_epo_low'     => [ 'mysql-ens-compara-prod-2', 'carlac_fish_epo_low_coverage_97' ],
    # 'fish_epo_anchors' => [ 'mysql-ens-compara-prod-5', 'muffato_generate_anchors_fish_96' ],

    ## primates
    # 'primates_epo'         => [ 'mysql-ens-compara-prod-6', 'waakanni_primates_epo_96' ],
    # 'primates_epo_prev'   => [ 'mysql-ens-compara-prod-2', 'mateus_mammals_epo_96' ],      # Primates are reused from mammals of the *same release* (same anchors and subset of species)
    # 'primates_epo_low'     => [ 'mysql-ens-compara-prod-3', 'muffato_primates_epo_low_coverage_96' ],
    # 'primates_epo_anchors' => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    # other alignments
    # 'amniotes_pecan'      => [ 'mysql-ens-compara-prod-8', 'muffato_amniotes_mercator_pecan_97' ],
    # 'amniotes_pecan_prev' => [ 'mysql-ens-compara-prod-5', 'muffato_amniotes_mercator_pecan_96b' ],

    # 'compara_syntenies'   => [ 'mysql-ens-compara-prod-2', 'carlac_ensembl_synteny_97' ],

    # miscellaneous
    # 'alt_allele_projection' => [ 'mysql-ens-compara-prod-2', 'carlac_ensembl_alt_allele_import_97' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ------------------------- NON-COMPARA DATABASES ------------------------------

my $ancestral_dbs = {
    'ancestral_curr' => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$curr_release" ],
    'ancestral_prev' => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$prev_release" ],

    # 'mammals_ancestral'    => [ 'mysql-ens-compara-prod-5', 'jalvarez_mammals_ancestral_core_99' ],
    # 'primates_ancestral'   => [ 'mysql-ens-compara-prod-3', 'mateus_primates_ancestral_core_98' ],
    # 'sauropsids_ancestral' => [ 'mysql-ens-compara-prod-8', 'dthybert_sauropsids_ancestral_core_99' ],
    # 'fish_ancestral'       => [ 'mysql-ens-compara-prod-1', 'cristig_fish_ancestral_core_99' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $ancestral_dbs );

Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-1', 'ncbi_taxonomy' ],
});

# ------------------------------------------------------------------------------

1;
