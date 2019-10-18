#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
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

# ----------------------CITEST CORE DATABASES------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $citest_core_dbs = {}; # TAG: <core_dbs_hash>

Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $citest_core_dbs );

# ---------------------PREVIOUS CORE DATABASES-----------------------

# Previous release core databases will ONLY be required by:
#   * PrepareMasterDatabaseForRelease_conf
#   * LoadMembers_conf
#   * MercatorPecan_conf
# !!! COMMENT THIS SECTION OUT FOR ALL OTHER PIPELINES (for speed) !!!

# my $suffix_separator = '__cut_here__';
# Bio::EnsEMBL::Registry->load_registry_from_db(
#    -host           => 'mysql-ens-mirror-1',
#    -port           => 4240,
#    -user           => 'ensro',
#    -pass           => '',
#    -db_version     => $prev_release,
#    -species_suffix => $suffix_separator.$prev_release,
# );

#---------------------COMPARA DATABASE LOCATIONS---------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    # General compara dbs
    'compara_master' => [ '', '' ], # TAG: <master_db_info>
    # 'compara_curr'   => [ 'mysql-ens-compara-prod-1', "ensembl_compara_$curr_release" ],
    # 'compara_prev'   => [ 'mysql-ens-compara-prod-1', "ensembl_compara_$prev_release" ],

    # Homology dbs
    # 'compara_members'      => [ 'mysql-ens-compara-prod-', '' ],
    # 'compara_ptrees'       => [ 'mysql-ens-compara-prod-', '' ],
    # 'ptrees_prev'          => [ 'mysql-ens-compara-prod-', '' ],
    # 'compara_families'     => [ 'mysql-ens-compara-prod-', '' ],
    # 'compara_nctrees'      => [ 'mysql-ens-compara-prod-', '' ],
    # 'nctrees_prev'         => [ 'mysql-ens-compara-prod-', '' ],
    # 'murinae_ptrees'       => [ 'mysql-ens-compara-prod-', '' ],
    # 'murinae_nctrees'      => [ 'mysql-ens-compara-prod-', '' ],
    # 'murinae_ptrees_prev'  => [ 'mysql-ens-compara-prod-', '' ],
    # 'murinae_nctrees_prev' => [ 'mysql-ens-compara-prod-', '' ],
    # 'sus_ptrees'           => [ 'mysql-ens-compara-prod-', '' ],
    # 'sus_nctrees'          => [ 'mysql-ens-compara-prod-', '' ],
    # 'sus_ptrees_prev'      => [ 'mysql-ens-compara-prod-', '' ],
    # 'sus_nctrees_prev'     => [ 'mysql-ens-compara-prod-', '' ],

    # LastZ dbs
    # 'lastz_batch_1'  => [ 'mysql-ens-compara-prod-', '' ],
    # 'lastz_batch_2'  => [ 'mysql-ens-compara-prod-', '' ],

    # EPO dbs
    ## Mammals
    # 'mammals_epo'         => [ 'mysql-ens-compara-prod-', '' ],
    # 'mammals_epo_prev'    => [ 'mysql-ens-compara-prod-', '' ],
    # 'mammals_epo_low'     => [ 'mysql-ens-compara-prod-', '' ],
    # 'mammals_epo_anchors' => [ 'mysql-ens-compara-prod-', '' ],

    ## Sauropsids
    # 'sauropsids_epo'         => [ 'mysql-ens-compara-prod-', '' ],
    # 'sauropsids_epo_prev'    => [ 'mysql-ens-compara-prod-', '' ],
    # 'sauropsids_epo_low'     => [ 'mysql-ens-compara-prod-', '' ],
    # 'sauropsids_epo_anchors' => [ 'mysql-ens-compara-prod-', '' ],

    ## Fish
    # 'fish_epo'         => [ 'mysql-ens-compara-prod-', '' ],
    # 'fish_epo_prev'    => [ 'mysql-ens-compara-prod-', '' ],
    # 'fish_epo_low'     => [ 'mysql-ens-compara-prod-', '' ],
    # 'fish_epo_anchors' => [ 'mysql-ens-compara-prod-', '' ],

    ## Primates
    # NOTE: Primates are reused from mammals of the *same release* (same anchors and subset of species)
    # 'primates_epo'         => [ 'mysql-ens-compara-prod-', '' ],
    # 'primates_epo_prev'    => [ 'mysql-ens-compara-prod-', '' ],
    # 'primates_epo_low'     => [ 'mysql-ens-compara-prod-', '' ],
    # 'primates_epo_anchors' => [ 'mysql-ens-compara-prod-', '' ],

    ## Pig strains
    # 'pig_strains_epo'         => [ 'mysql-ens-compara-prod-', '' ],
    # 'pig_strains_epo_prev'    => [ 'mysql-ens-compara-prod-', '' ],
    # 'pig_strains_epo_low'     => [ 'mysql-ens-compara-prod-', '' ],
    # 'pig_strains_epo_anchors' => [ 'mysql-ens-compara-prod-', '' ],

    # Other alignments
    # 'amniotes_pecan'      => [ 'mysql-ens-compara-prod-', '' ],
    # 'amniotes_pecan_prev' => [ 'mysql-ens-compara-prod-', '' ],

    # 'compara_syntenies' => [ 'mysql-ens-compara-prod-', '' ],

    # Miscellaneous
    # 'alt_allele_projection' => [ 'mysql-ens-compara-prod-', '' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# my $ancestral_dbs = {
#     'ancestral_prev' => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$prev_release" ],
#     'ancestral_curr' => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$curr_release" ],
# };

# Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $ancestral_dbs );

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-1', 'ncbi_taxonomy' ],
});

# -------------------------------------------------------------------

1;
