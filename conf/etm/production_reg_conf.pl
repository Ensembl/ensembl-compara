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

my @overlap_species = (
    'avena_sativa_ot3098',
    'caenorhabditis_elegans',
    'drosophila_melanogaster',
    'hordeum_vulgare',
    'hordeum_vulgare_barke',
    'oryza_sativa',
    'oryza_sativa_ir64',
    'saccharomyces_cerevisiae',
    'solanum_lycopersicum_gca000188115v5cm',
);
Bio::EnsEMBL::Compara::Utils::Registry::suppress_overlap_species_warnings(\@overlap_species);

# ---------------------- CURRENT CORE DATABASES----------------------------------

# Use our mirror (which has all the databases)
Bio::EnsEMBL::Registry->load_registry_from_url('mysql://ensro@mysql-ens-vertannot-staging:4573/116');

# Ensure we're using the correct cores for species that overlap with other divisions
Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
my $overlap_cores = {
    'caenorhabditis_elegans' => [ 'mysql-ens-vertannot-staging', "caenorhabditis_elegans_core_116_282" ],
    'drosophila_melanogaster' => [ 'mysql-ens-vertannot-staging', "drosophila_melanogaster_core_116_11" ],
    'saccharomyces_cerevisiae' => [ 'mysql-ens-vertannot-staging', "saccharomyces_cerevisiae_core_116_4" ],

    'avena_sativa_ot3098' => [ 'mysql-ens-compara-exp', 'avena_sativa_ot3098_core_63_116_1' ],
    'hordeum_vulgare' => [ 'mysql-ens-compara-exp', 'hordeum_vulgare_core_63_116_4' ],
    'hordeum_vulgare_barke' => [ 'mysql-ens-compara-exp', 'hordeum_vulgare_barke_core_63_116_1' ],
    'oryza_sativa' => [ 'mysql-ens-compara-exp', 'oryza_sativa_core_63_116_7' ],
    'oryza_sativa_ir64' => [ 'mysql-ens-compara-exp', 'oryza_sativa_ir64_core_63_116_1' ],
    'solanum_lycopersicum_gca000188115v5cm' => [ 'mysql-ens-compara-exp', 'solanum_lycopersicum_gca000188115v5cm_core_63_116_1' ],
};
Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $overlap_cores );

my $additional_cores = {
    'arabidopsis_thaliana_gca001651475v1gb' => [ 'mysql-ens-compara-exp', 'arabidopsis_thaliana_gca001651475v1gb_core_62_114_1' ],
    'arabidopsis_thaliana_gca978657495v1gb' => [ 'mysql-ens-compara-exp', 'arabidopsis_thaliana_gca978657495v1gb_core_114_1' ],
    'brassica_napus_gca905183035v1gb' => [ 'mysql-ens-compara-exp', 'brassica_napus_gca905183035v1gb_core_62_114_1' ],
};
Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $additional_cores );

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease and LoadMembers only
*Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-mirror-3',
        -port   => 4275,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => 116,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
    Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
    Bio::EnsEMBL::Compara::Utils::Registry::remove_multi(undef, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-mirror-1',
        -port   => 4240,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => 116,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
};
#------------------------COMPARA DATABASE LOCATIONS----------------------------------

my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-exp', 'ensembl_compara_master_etm_20260729' ],
    'compara_prev'   => [ 'mysql-ens-mirror-3', 'ensembl_compara_plants_63_116' ],

    'master_prep'    => [ 'mysql-ens-compara-exp', 'twalsh_prepare_etm_master_for_rel_20260805' ],

    # homology dbs
    #'compara_members'        => [ 'mysql-ens-compara-exp', '' ],
    #'compara_ptrees'         => [ 'mysql-ens-compara-exp', '' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database:
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-mirror-3', 'ncbi_taxonomy_116' ],
});

# -------------------------------------------------------------------

1;
