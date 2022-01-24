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
my $curr_eg_release = $ENV{'CURR_EG_RELEASE'};
my $prev_eg_release = $curr_eg_release - 1;


# ---------------------- CURRENT CORE DATABASES----------------------------------

# Non-Vertebrates server
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");
# Protist collections
my @collection_groups = qw(
    alveolata1
    amoebozoa1
    apusozoa1
    choanoflagellida1
    cryptophyta1
    euglenozoa1
    fornicata1
    heterolobosea1
    ichthyosporea1
    nucleariidaeandfonticulagroup1
    parabasalia1
    rhizaria1
    stramenopiles1
);
foreach my $group ( @collection_groups ) {
    Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
        -host   => 'mysql-ens-sta-3-b',
        -port   => 4686,
        -user   => 'ensro',
        -pass   => '',
        -dbname => "protists_${group}_collection_core_${curr_eg_release}_${curr_release}_1",
    );
}

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease and LoadMembers only
*Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host   => 'mysql-ens-sta-3',
        -port   => 4160,
        -user   => 'ensro',
        -pass   => '',
        -db_version     => $prev_release,
        -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
    );
    # Protist Collections
    foreach my $group ( @collection_groups ) {
        Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
            -host   => 'mysql-ens-sta-3',
            -port   => 4160,
            -user   => 'ensro',
            -pass   => '',
            -dbname => "protists_${group}_collection_core_${prev_eg_release}_${prev_release}_1",
        );
    }
};

#------------------------COMPARA DATABASE LOCATIONS----------------------------------


my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-8', 'ensembl_compara_master_protists' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-8', "ensembl_compara_protists_${curr_eg_release}_${curr_release}" ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-8', "ensembl_compara_protists_${prev_eg_release}_${prev_release}" ],

    # homology dbs
    # 'compara_members'  => [ 'mysql-ens-compara-prod-x', '' ],
    # 'compara_ptrees'   => [ 'mysql-ens-compara-prod-x', '' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-3-b', "ncbi_taxonomy_${curr_release}" ],
});

# -------------------------------------------------------------------

1;
