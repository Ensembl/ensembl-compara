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
my $curr_eg_release = $ENV{'CURR_EG_RELEASE'};
my $prev_eg_release = $curr_eg_release - 1;

# ---------------------- CURRENT CORE DATABASES----------------------------------

# most cores are on EG servers, but some are on ensembl's vertannot-staging
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-3:4160/$curr_release");
#Bio::EnsEMBL::Registry->remove_DBAdaptor('saccharomyces_cerevisiae', 'core'); # never use EG's version of yeast

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by PrepareMasterDatabaseForRelease and LoadMembers only
# !!! COMMENT THIS SECTION OUT FOR ALL OTHER PIPELINES (for speed) !!!
#my $suffix_separator = '__cut_here__';
#Bio::EnsEMBL::Registry->load_registry_from_db(
#    -host   => 'mysql-ens-mirror-3',
#    -port   => 4275,
#    -user   => 'ensro',
#    -pass   => '',
#    -db_version     => $prev_release,
#    -species_suffix => $suffix_separator.$prev_release,
#);
#Bio::EnsEMBL::Registry->remove_DBAdaptor('saccharomyces_cerevisiae'.$suffix_separator.$prev_release, 'core'); # never use EG's version of yeast
#Bio::EnsEMBL::Registry->load_registry_from_db(
#    -host   => 'mysql-ens-mirror-1',
#    -port   => 4240,
#    -user   => 'ensro',
#    -pass   => '',
#    -db_version     => $prev_release,
#    -species_suffix => $suffix_separator.$prev_release,
#);
#------------------------COMPARA DATABASE LOCATIONS----------------------------------


my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-7', 'ensembl_compara_master_pan' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-7', "ensembl_compara_pan_homology_${curr_eg_release}_${curr_release}" ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-7', "ensembl_compara_pan_homology_${prev_eg_release}_${prev_release}" ],

    # homology dbs
    'compara_members'  => [ 'mysql-ens-compara-prod-7', 'muffato_pan_load_members_100'  ],
    'compara_ptrees'   => [ 'mysql-ens-compara-prod-7', 'muffato_pan_protein_trees_100' ],
};

Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::Utils::Registry::add_taxonomy_dbas({
    'ncbi_taxonomy' => [ 'mysql-ens-sta-1', "ncbi_taxonomy_${curr_release}" ],
});

# -------------------------------------------------------------------

1;
