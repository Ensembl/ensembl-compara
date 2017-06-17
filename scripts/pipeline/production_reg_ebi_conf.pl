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
use Bio::EnsEMBL::Hive::DBSQL::DBAdaptor;

# ------------------------- CORE DATABASES: --------------------------------------

# The majority of core databases live on two staging servers:
 Bio::EnsEMBL::Registry->load_registry_from_url(
   'mysql://ensro@mysql-ens-sta-1.ebi.ac.uk:4519/90');

# # Extra core databases that live on genebuilders' servers:
# Bio::EnsEMBL::Registry->remove_DBAdaptor('gallus_gallus', 'core'); # deregister old version
# Bio::EnsEMBL::DBSQL::DBAdaptor->new(
#     -host => 'genebuild12',
#     -user => 'ensro',
#     -port => 3306,
#     -species => 'gallus_gallus',
#     -group => 'core',
#     -dbname => 'th3_chicken_core_mt',
# );

# Bio::EnsEMBL::Registry->remove_DBAdaptor('mus_musculus', 'core'); # deregister old version
# Bio::EnsEMBL::DBSQL::DBAdaptor->new(
#     -host => 'ens-staging2',
#     -user => 'ensro',
#     -port => 3306,
#     -species => 'mus_musculus',
#     -group => 'core',
#     -dbname => 'mus_musculus_core_86_38',
# );


# ------------------------- COMPARA DATABASES: -----------------------------------

# # Individual pipeline database for ProteinTrees:
# Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#      -host => 'mysql-treefam-prod',
#      -user => 'ensadmin',
#      -pass => $ENV{'ENSADMIN_PSW'},
#      -port => 4401,
#      -species => 'compara_ptrees',
#      -dbname => 'mateus_protein_trees_89',
# );

# #Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
# #     -host => 'mysql-ens-compara-prod-1',
# #     -user => 'ensadmin',
# #     -pass => $ENV{'ENSADMIN_PSW'},
# #     -port => 4485,
# #     -species => 'compara_mouse_strains_homologies',
# #     -dbname => 'muffato_mouse_strain_homologies_88',
# #);

# # Individual pipeline database for ncRNAtrees:
#  Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#      -host => 'mysql-ens-compara-prod-3',
#      -user => 'ensadmin',
#      -pass => $ENV{'ENSADMIN_PSW'},
#      -port => 4523,
#      -species => 'compara_nctrees',
#      -dbname => 'muffato_ensembl_ebinc_rna_trees_89c',
#  );

# # # Individual pipeline database for Families:
#  Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#      -host => 'mysql-ens-compara-prod-2',
#      -user => 'ensadmin',
#      -pass => $ENV{'ENSADMIN_PSW'},
#      -port => 4522,
#      -species => 'compara_families',
#      -dbname => 'waakanni_ensembl_families_ebi_89',
#);

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

# ------------------------- EPO DATABASES: -----------------------------------


# -----------------------OTHER ALIGNMENTS-------------------------------

# ----------------------------------------------------------------------

# Merged homologies
#Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(
    # eHive DBAdaptor only accepts a URL
#     -url  => 'mysql://ensadmin:'.$ENV{'ENSADMIN_PSW'}.'@compara1:3306/mm14_pipeline_hom_final_merge_86',
#     -species => 'homologies_merged',
#     -no_sql_schema_version_check => 1,
#);

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
    -species => 'ancestral_prev',
    -dbname => 'mateus_ensembl_ancestral_89',
);

# current ancestral database on one of Compara servers:
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'ancestral_curr',
    -dbname => 'waakanni_ensembl_ancestral_90',
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

1;
