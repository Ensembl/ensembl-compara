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

my $curr_release = $ENV{'CURR_ENSEMBL_RELEASE'};
my $prev_release = $curr_release - 1;

# ---------------------- CURRENT CORE DATABASES---------------------------------

my $vert_annot = 'mysql://ensro@mysql-ens-vertannot-staging:4573';
my $staging1   = 'mysql://ensro@mysql-ens-sta-1:4519';
my $staging1b  = 'mysql://ensro@mysql-ens-sta-1-b:4519';
my $mirror     = 'mysql://ensro@mysql-ens-mirror-1:4240';

# All the core databases live on the Vertebrates staging server or our mirror
# Bio::EnsEMBL::Registry->load_registry_from_url("$mirror/100");
# Bio::EnsEMBL::Registry->load_registry_from_url("$mirror/101");
# Bio::EnsEMBL::Registry->load_registry_from_url("$staging1/102");
# Bio::EnsEMBL::Registry->load_registry_from_url("$staging1b/103");
Bio::EnsEMBL::Registry->load_registry_from_url("$vert_annot/104");

# Add in extra cores from genebuild server
# my $extra_core_dbs = {
#     'cyprinus_carpio_german_mirror' => [ 'mysql-ens-vertannot-staging', "cyprinus_carpio_germanmirror_core_99_10" ],
#     'cyprinus_carpio_hebao_red' => [ 'mysql-ens-vertannot-staging', "cyprinus_carpio_hebaored_core_99_10" ],
# };
#
# Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $extra_core_dbs );

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease, LoadMembers and MercatorPecan
# *Bio::EnsEMBL::Compara::Utils::Registry::load_previous_core_databases = sub {
#     Bio::EnsEMBL::Registry->load_registry_from_db(
#         -host   => 'mysql-ens-mirror-1',
#         -port   => 4240,
#         -user   => 'ensro',
#         -pass   => '',
#         -db_version     => $prev_release,
#         -species_suffix => Bio::EnsEMBL::Compara::Utils::Registry::PREVIOUS_DATABASE_SUFFIX,
#     );
# };

#------------------------COMPARA DATABASE LOCATIONS----------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    'compara_master'     => [ 'mysql-ens-compara-prod-1', 'ensembl_compara_master' ],
    'compara_references' => [ 'mysql-ens-compara-prod-4', 'carlac_reference_db_test' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-1', "ncbi_taxonomy_$curr_release" ],
});

# -------------------------------------------------------------------

1;
