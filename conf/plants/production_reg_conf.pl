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
my $curr_eg_release = $curr_release - 53;
my $prev_eg_release = $curr_eg_release - 1;

# Species found on both vertebrates and non-vertebrates servers
my @overlap_species = qw(saccharomyces_cerevisiae drosophila_melanogaster caenorhabditis_elegans);

# ---------------------- DATABASE HOSTS -----------------------------------------

my ($curr_vert_host, $curr_vert_port, $curr_nv_host, $curr_nv_port);
if ($curr_release % 2 == 0) {
    ($curr_vert_host, $curr_vert_port) = ('mysql-ens-sta-1', 4519);
    ($curr_nv_host, $curr_nv_port)     = ('mysql-ens-sta-3', 4160);
} else {
    ($curr_vert_host, $curr_vert_port) = ('mysql-ens-sta-1-b', 4685);
    ($curr_nv_host, $curr_nv_port)     = ('mysql-ens-sta-3-b', 4686);
}

my ($prev_vert_host, $prev_vert_port, $prev_nv_host, $prev_nv_port);
if ($prev_release % 2 == 0) {
    ($prev_vert_host, $prev_vert_port) = ('mysql-ens-sta-1', 4519);
    ($prev_nv_host, $prev_nv_port)     = ('mysql-ens-sta-3', 4160);
} else {
    ($prev_vert_host, $prev_vert_port) = ('mysql-ens-sta-1-b', 4685);
    ($prev_nv_host, $prev_nv_port)     = ('mysql-ens-sta-3-b', 4686);
}

# ---------------------- CURRENT CORE DATABASES----------------------------------

# Use our mirror (which has all the databases)
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");

# Ensure we're using the correct cores for species that overlap with other divisions
Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
my $overlap_cores = {
    'drosophila_melanogaster' => [ 'mysql-ens-vertannot-staging', "drosophila_melanogaster_core_${curr_release}_11" ],
    'caenorhabditis_elegans'  => [ 'mysql-ens-vertannot-staging', "caenorhabditis_elegans_core_${curr_release}_282" ],
    'saccharomyces_cerevisiae' => [ 'mysql-ens-vertannot-staging', "saccharomyces_cerevisiae_core_${curr_release}_4" ],
};
Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $overlap_cores );

# ---------------------- CURRENT CORE DATABASES : ALTERNATE HOSTS ----------------

# Use the official staging servers
#Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@$curr_nv_host:$curr_nv_port/$curr_release");
# and remove the Non-Vertebrates version of the shared species
#Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
#Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();
# before loading the Vertebrates version
#Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@$curr_vert_host:$curr_vert_port/$curr_release");

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease and LoadMembers only
*Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => $prev_nv_host,
        -port   => $prev_nv_port,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
    Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
    Bio::EnsEMBL::Compara::Utils::Registry::remove_multi(undef, Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX);
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => $prev_vert_host,
        -port   => $prev_vert_port,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
};
#------------------------COMPARA DATABASE LOCATIONS----------------------------------


my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-5', 'ensembl_compara_master_plants' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-5', "ensembl_compara_plants_${curr_eg_release}_${curr_release}" ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-5', "ensembl_compara_plants_${prev_eg_release}_${prev_release}" ],

    # homology dbs
    'compara_members'        => [ 'mysql-ens-compara-prod-5', 'twalsh_plants_load_members_114'],
    #'compara_ptrees'         => [ 'mysql-ens-compara-prod-5', '' ],
    'rice_cultivars_ptrees'  => [ 'mysql-ens-compara-prod-7', 'twalsh_rice_cultivars_plants_protein_trees_lsf_112' ],
    'wheat_cultivars_ptrees' => [ 'mysql-ens-compara-prod-6', 'thiagogenez_wheat_cultivars_plants_protein_trees_113' ],

    # LASTZ dbs
    #'lastz_batch_1'  => [ 'mysql-ens-compara-prod-X', '' ],

    # other alignments
    #'wheat_cactus'   => [ 'mysql-ens-compara-prod-X', '' ],

    # synteny
    #'compara_syntenies' => [ 'mysql-ens-compara-prod-X', '' ],

    # EPO dbs
    ## rice
    'rice_epo_high_low' => [ 'mysql-ens-compara-prod-5', "ensembl_compara_plants_${prev_eg_release}_${prev_release}" ],
    'rice_epo_prev'     => [ 'mysql-ens-compara-prod-5', "ensembl_compara_plants_${prev_eg_release}_${prev_release}" ],
    'rice_epo_anchors'  => [ 'mysql-ens-compara-prod-5', 'cristig_generate_anchors_rice_99' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------
my $ancestral_dbs = {
    'ancestral_prev' => [ 'mysql-ens-compara-prod-5', "ensembl_ancestral_plants_${prev_eg_release}_$prev_release" ],
    #'ancestral_curr' => [ 'mysql-ens-compara-prod-5', "ensembl_ancestral_plants_${curr_eg_release}_$curr_release" ],

    # 'rice_ancestral' => [ 'mysql-ens-compara-prod-5', "ensembl_ancestral_plants_${prev_eg_release}_$prev_release" ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $ancestral_dbs );

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ $curr_nv_host, "ncbi_taxonomy_$curr_release" ],
});

# -------------------------------------------------------------------

1;
