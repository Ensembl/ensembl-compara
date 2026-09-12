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

# Please update this file before starting comparative processing
# and check the changes back into GIT for everyone's benefit.

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::Registry;

# ---------------------- CURRENT CORE DATABASES----------------------------------

# e116 core databases
Bio::EnsEMBL::Registry->load_registry_from_url('mysql://ensro@mysql-ens-compara-prod-1:4485/116');

# additional core databases
my $additional_cores = {
    'arabidopsis_thaliana_gca001651475v1gb' => [ 'mysql-ens-compara-prod-1', 'arabidopsis_thaliana_gca001651475v1gb_core_62_114_1' ],
    'arabidopsis_thaliana_gca978657495v1gb' => [ 'mysql-ens-compara-prod-1', 'arabidopsis_thaliana_gca978657495v1gb_core_114_1' ],
    'avena_sativa_gca022788535v1'           => [ 'mysql-ens-compara-prod-1', 'avena_sativa_gca022788535v1_core_110_1' ],
    'brassica_napus_gca905183035v1gb'       => [ 'mysql-ens-compara-prod-1', 'brassica_napus_gca905183035v1gb_core_62_114_1' ],
    'hordeum_vulgare'                       => [ 'mysql-ens-compara-prod-1', 'hordeum_vulgare_core_57_110_4' ],
    'hordeum_vulgare_gca949782835v1cm'      => [ 'mysql-ens-compara-prod-1', 'hordeum_vulgare_gca949782835v1cm_core_114_1' ],
    'oryza_sativa_gca001433935v1cm'         => [ 'mysql-ens-compara-prod-1', 'oryza_sativa_gca001433935v1cm_core_114_1' ],
    'oryza_sativa_gca009914875v1'           => [ 'mysql-ens-compara-prod-1', 'oryza_sativa_gca009914875v1_core_110_1' ],
    'solanum_lycopersicum_gca000188115v5cm' => [ 'mysql-ens-compara-prod-1', 'solanum_lycopersicum_gca000188115v5cm_core_114_1' ],
};
Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $additional_cores );

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease and LoadMembers only
*Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-sta-3',
        -port   => 4160,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => 116,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
    Bio::EnsEMBL::Compara::Utils::Registry::remove_multi(undef, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-sta-1',
        -port   => 4519,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => 116,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
};

#------------------------COMPARA DATABASE LOCATIONS----------------------------------

my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-exp', 'ensembl_compara_master_etm_20260909' ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-5', 'ensembl_compara_plants_63_116' ],

    # production setup
    #'master_prep' => [ 'mysql-ens-compara-exp', '' ],

    # homology dbs
    #'compara_members' => [ 'mysql-ens-compara-exp', '' ],
    #'compara_ptrees'  => [ 'mysql-ens-compara-exp', '' ],

    # dump pipeline
    #'compara_dumps' => [ 'mysql-ens-compara-exp', '' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database:
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-mirror-3', 'ncbi_taxonomy_116' ],
});

# -------------------------------------------------------------------

1;
