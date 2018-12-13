#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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
use Bio::EnsEMBL::Utils::ConfigRegistry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor;

my $current_release = 95;

# ---------------------- CURRENT CORE DATABASES----------------------------------

# most cores are on EG servers, but some are on ensembl's vertannot-staging
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro@mysql-eg-prod-2:4239/$current_release");
Bio::EnsEMBL::Registry->remove_DBAdaptor('saccharomyces_cerevisiae', 'core'); # never use EG's version of yeast
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro@mysql-ens-vertannot-staging:4573/$current_release");

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by LoadMembers only
# !!! COMMENT THIS SECTION OUT FOR ALL OTHER PIPELINES (for speed) !!!

my $suffix_separator = '__cut_here__';
my $prev_release = $current_release - 1;
Bio::EnsEMBL::Registry->load_registry_from_db(
    -host   => 'mysql-eg-mirror',
    -port   => 4157,
    -user   => 'ensro',
    -pass   => '',
    -db_version     => $prev_release,
    -species_suffix => $suffix_separator.$prev_release,
);
Bio::EnsEMBL::Registry->remove_DBAdaptor('saccharomyces_cerevisiae'.$suffix_separator.$prev_release, 'core'); # never use EG's version of yeast
Bio::EnsEMBL::Registry->load_registry_from_db(
    -host   => 'mysql-ensembl-mirror',
    -port   => 4240,
    -user   => 'ensro',
    -pass   => '',
    -db_version     => $prev_release,
    -species_suffix => $suffix_separator.$prev_release,
);

#-------------------------HOMOLOGY DATABASES-----------------------------------
# Members
 Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-2',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4522,
     -species => 'compara_members',
     -dbname => 'muffato_load_members_95_plants',
 );

# Individual pipeline database for ProteinTrees:
 Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
      -host => 'mysql-ens-compara-prod-5',
      -user => 'ensadmin',
      -pass => $ENV{'ENSADMIN_PSW'},
      -port => 4615,
      -species => 'compara_ptrees',
      -dbname => 'mateus_plants_prottrees_42_95',
 );

# protein trees from previous release - for GOC reuse
 Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-4',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4401,
    -species => 'ptrees_prev',
    -dbname => 'carlac_plants_prottrees_41_94_B ',
);

# ------------------------- LASTZ DATABASES: -----------------------------------

#Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#    -host => 'mysql-ens-compara-prod-3',
#    -user => 'ensadmin',
#    -pass => $ENV{'ENSADMIN_PSW'},
#    -port => 4523,
#    -species => 'plants_lastz_mtru',
#    -dbname => 'carlac_eg_lastz_plants_mtru_ref',
#);

# SYNTENIES
# mysql-ens-compara-prod-2.ebi.ac.uk:4522/waakanni_plants_synteny_94
#Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#    -host => 'mysql-ens-compara-prod-2',
#    -user => 'ensadmin',
#    -pass => $ENV{'ENSADMIN_PSW'},
#    -port => 4522,
#    -species => 'plants_synteny',
#    -dbname => 'waakanni_plants_synteny_94',
#);

# ----------------------COMPARA DATABASES---------------------------

# Compara Master database:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4615,
    -species => 'compara_master',
    -dbname => 'ensembl_compara_master_plants',
);

# previous release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4615,
    -species => 'compara_prev',
    -dbname => 'ensembl_compara_plants_41_94',
);

# current release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4615,
    -species => 'compara_curr',
    -dbname => 'ensembl_compara_plants_42_95',
);

# ensembl production (maintained by production team):
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-sta-1',
    -user => 'ensro',
    -port => 4519,
    -species => 'ensembl_production',
    -dbname => 'ensembl_production_95',
    -group => 'production',
);

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor->new(
    -host => 'mysql-ens-sta-1',
    -user => 'ensro',
    -port => 4519,
    -group => 'taxonomy',
    -species => 'ncbi_taxonomy',
    -dbname => 'ncbi_taxonomy',
);


1;
