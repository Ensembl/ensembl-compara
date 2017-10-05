#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
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

# -------------------------CORE DATABASES--------------------------------------

# The majority of core databases live on staging servers:
 # Bio::EnsEMBL::Registry->load_registry_from_url(
 #   'mysql://ensro@mysql-ens-sta-1.ebi.ac.uk:4519/90');
  Bio::EnsEMBL::Registry->load_registry_from_url(
   'mysql://ensro@mysql-ens-general-prod-1:4525/90');

# # Extra core databases that live on genebuilders' servers:
# Bio::EnsEMBL::Registry->remove_DBAdaptor('sus_scrofa', 'core'); # deregister old version
# Bio::EnsEMBL::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-1',
#     -user => 'ensro',
#     -port => 4485,
#     -species => 'sus_scrofa',
#     -group => 'core',
#     -dbname => 'sus_scrofa_core_90',
# );

#-------------------------HOMOLOGY DATABASES-----------------------------------

# Individual pipeline database for ProteinTrees:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4485,
     -species => 'compara_ptrees',
     -dbname => 'muffato_protein_trees_90b',
);

# Individual pipeline database for Families:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-2',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4522,
     -species => 'compara_families',
     -dbname => 'carlac_families_90',
);

# Individual pipeline database for ncRNAtrees:
 Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-4',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4401,
     -species => 'compara_nctrees',
     -dbname => 'mateus_compara_nctrees_90',
 );

# Mouse strains protein trees:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-3',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4523,
    -species => 'murinae_ptrees',
    -dbname => 'carlac_murinae_protein_trees_90',
);

# Mouse strains ncRNA trees:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-4',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4401,
    -species => 'murinae_nctrees',
    -dbname => 'mateus_murinae_nctrees_90',
);

# ------------------------- LASTZ DATABASES: -----------------------------------

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4485,
     -species => 'pig_lastz_1',
     -dbname => 'carlac_pig_lastz_90',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4523,
     -species => 'pig_lastz_2',
     -dbname => 'mateus_human_pig_lastz_90',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-2',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4522,
     -species => 'pig_lastz_3',
     -dbname => 'waakanni_lastz_90',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4523,
     -species => 'mice_lastz_1',
     -dbname => 'carlac_mice_lastz_human_90',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4485,
     -species => 'mice_lastz_2',
     -dbname => 'carlac_mice_lastz_mouse_90',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4523,
     -species => 'rodents_lastz',
     -dbname => 'ensembl_compara_rodents_89',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-2',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4522,
     -species => 'mouse_spretus_lastz',
     -dbname => 'carlac_mouse_spretus_lastz_90',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4523,
     -species => 'human_cho_lastz',
     -dbname => 'carlac_cho_human_lastz_90',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4523,
     -species => 'mouse_cho_lastz',
     -dbname => 'db8_hrzcho_cricetulus_griseus_lastz_89b',
     -group => 'compara',
);

# ------------------------- EPO DATABASES: -----------------------------------

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4523,
     -species => 'mammals_epo',
     -dbname => 'muffato_mammals_epo_90b',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-4',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4401,
     -species => 'mammals_epo2x',
     -dbname => 'carlac_epo_low_55way_mammals_90',
);

# -----------------------OTHER ALIGNMENTS-------------------------------

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-2',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4522,
     -species => 'mammals_pecan',
     -dbname => 'muffato_27mammals_pecan_90',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4485,
     -species => 'compara_syntenies',
     -dbname => 'muffato_synteny_90',
);

# ----------------------COMPARA DATABASES---------------------------

# Compara Master database:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'compara_master',
    -dbname => 'ensembl_compara_master',
);

# previous release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'compara_prev',
    -dbname => 'ensembl_compara_89',
);

# current release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'compara_curr',
    -dbname => 'ensembl_compara_90',
);

# previous ancestral database on one of Compara servers:
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -group => 'core',
    -species => 'ancestral_prev',
    -dbname => 'waakanni_ensembl_ancestral_89',
);

# current ancestral database on one of Compara servers:
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -group => 'core',
    -species => 'ancestral_curr',
    -dbname => 'ensembl_ancestral_90',
);

# ensembl production (maintained by production team):
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-sta-1',
    -user => 'ensro',
    -port => 4519,
    -species => 'ensembl_production',
    -dbname => 'ensembl_production',
    -group => 'production',
);

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor->new(
    -host => 'mysql-ens-sta-1.ebi.ac.uk',
    -user => 'ensro',
    -port => 4519,
    -group => 'taxonomy',
    -species => 'ncbi_taxonomy',
    -dbname => 'ncbi_taxonomy',
);

# # ---------------------OTHER DATABASES-----------------------------

# # Members
# Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-2',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4522,
#     -species => 'compara_members',
#     -dbname => 'muffato_load_members_90_ensembl',
# );

# # Merge alignments
# Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-1',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4485,
#     -species => 'alignments_merged',
#     -dbname => 'ensembl_alignments_merged_90',
# );

# # Alt allele projection
# Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-1',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4485,
#     -species => 'alt_allele_projection',
#     -dbname => 'carlac_alt_allele_import_90',
# );

1;
