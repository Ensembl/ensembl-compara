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
my $core_dbs = {
    'gallus_gallus'        => [ 'mysql-ens-compara-prod-10', 'citest_gallus_gallus_core_99_6' ],
    'ciona_intestinalis'   => [ 'mysql-ens-compara-prod-10', 'citest_ciona_intestinalis_core_99_3' ],
    'anolis_carolinensis'  => [ 'mysql-ens-compara-prod-10', 'citest_anolis_carolinensis_core_99_2' ],
    'danio_rerio'          => [ 'mysql-ens-compara-prod-10', 'citest_danio_rerio_core_99_11' ],
    'homo_sapiens'         => [ 'mysql-ens-compara-prod-10', 'citest_homo_sapiens_core_99_38' ],
    'pan_troglodytes'      => [ 'mysql-ens-compara-prod-10', 'citest_pan_troglodytes_core_99_3' ],
    'mus_musculus'         => [ 'mysql-ens-compara-prod-10', 'citest_mus_musculus_core_99_38' ],
    'saccharum_spontaneum' => [ 'mysql-ens-compara-prod-10', 'citest_saccharum_spontaneum_core_46_99_1' ],
    'triticum_urartu'      => [ 'mysql-ens-compara-prod-10', 'citest_triticum_urartu_core_46_99_1' ],
    'canis_familiaris'     => [ 'mysql-ens-compara-prod-10', 'citest_canis_familiaris_core_99_31' ],
    'triticum_aestivum'    => [ 'mysql-ens-compara-prod-10', 'citest_triticum_aestivum_core_46_99_4' ],
    'triticum_dicoccoides' => [ 'mysql-ens-compara-prod-10', 'citest_triticum_dicoccoides_core_46_99_1' ],
    'lepisosteus_oculatus' => [ 'mysql-ens-compara-prod-10', 'citest_lepisosteus_oculatus_core_99_1' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $core_dbs );

# --------------------------- COMPARA DATABASES --------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    # General compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-10', 'ensembl_compara_master_citest' ],
    # 'compara_curr'   => [ 'mysql-ens-compara-prod-10', "compara_citest_$curr_release" ],
    # 'compara_prev'   => [ 'mysql-ens-compara-prod-10', "compara_citest_$prev_release" ],

    # Homology dbs
    # 'compara_members'      => [ 'mysql-ens-compara-prod-10', '' ],
    # 'compara_ptrees'       => [ 'mysql-ens-compara-prod-10', '' ],
    # 'ptrees_prev'          => [ 'mysql-ens-compara-prod-10', '' ],
    # 'compara_families'     => [ 'mysql-ens-compara-prod-10', '' ],
    # 'compara_nctrees'      => [ 'mysql-ens-compara-prod-10', '' ],
    # 'nctrees_prev'         => [ 'mysql-ens-compara-prod-10', '' ],

    # LastZ dbs
    # 'lastz_batch_1'  => [ 'mysql-ens-compara-prod-10', '' ],

    # EPO dbs
    ## Mammals with feathers
    # 'mammals_with_feathers_epo'         => [ 'mysql-ens-compara-prod-10', '' ],
    # 'mammals_with_feathers_prev'        => [ 'mysql-ens-compara-prod-10', '' ],
    # 'mammals_with_feathers_epo_low'     => [ 'mysql-ens-compara-prod-10', '' ],
    # 'mammals_with_feathers_epo_anchors' => [ 'mysql-ens-compara-prod-10', '' ],

    # Other alignments
    # 'amniotes_pecan'      => [ 'mysql-ens-compara-prod-10', '' ],
    # 'amniotes_pecan_prev' => [ 'mysql-ens-compara-prod-10', '' ],

    # 'compara_syntenies' => [ 'mysql-ens-compara-prod-10', '' ],

    # Miscellaneous
    # 'alt_allele_projection' => [ 'mysql-ens-compara-prod-10', '' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ------------------------- NON-COMPARA DATABASES ------------------------------

my $ancestral_dbs = {
    'ancestral_curr' => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$curr_release" ],
    'ancestral_prev' => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$prev_release" ],

    # 'mammals_with_feathers_ancestral' => [ 'mysql-ens-compara-prod-10', '' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $ancestral_dbs );

Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-1', "ncbi_taxonomy_$curr_release" ],
});

# ------------------------------------------------------------------------------

1;
