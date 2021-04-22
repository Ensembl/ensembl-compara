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

#my $curr_release = $ENV{'CURR_ENSEMBL_RELEASE'};
my $curr_release = 103;
my $prev_release = $curr_release - 1;
my $curr_eg_release = 50;
my $prev_eg_release = $curr_eg_release - 1;

# Species found on both vertebrates and non-vertebrates servers
my @overlap_species = qw(saccharomyces_cerevisiae drosophila_melanogaster caenorhabditis_elegans);

# ---------------------- CURRENT CORE DATABASES----------------------------------

# Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-mirror-1:4240/$curr_release");
# # But remove the non-vertebrates species
# Bio::EnsEMBL::Compara::Utils::Registry::remove_species(\@overlap_species);
# Bio::EnsEMBL::Compara::Utils::Registry::remove_multi();
# # Non-Vertebrates server
# Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-mirror-3:4275/$curr_release");
# # Bacteria server: all species used in qfo happen to be dispersed among these databases
# for my $i (0 .. 109) {
#     Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
#         -host   => 'mysql-ens-mirror-4',
#         -port   => 4495,
#         -user   => 'ensro',
#         -pass   => '',
#         -dbname => "bacteria_" . $i . "_collection_core_${curr_eg_release}_${curr_release}_1",
#     );
# }

#------------------------COMPARA DATABASE LOCATIONS----------------------------------

my $compara_dbs = {
    # general compara dbs
    #'compara_master' => [ 'mysql-ens-compara-prod-2', 'cristig_ensembl_compara_master_qfo' ],

    # homology dbs
    # 'compara_members'  => [ 'mysql-ens-compara-prod-X', '' ],
    # 'compara_ptrees'   => [ 'mysql-ens-compara-prod-X', '' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-mirror-1', "ncbi_taxonomy_${curr_release}" ],
});

# -------------------------------------------------------------------

1;
