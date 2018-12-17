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

# -------------------------CORE DATABASES--------------------------------------

# The majority of core databases live on staging servers:
   Bio::EnsEMBL::Registry->load_registry_from_url(
    'mysql://ensro@mysql-ens-sta-2.ebi.ac.uk:4520/95');
#  Bio::EnsEMBL::Registry->load_registry_from_url(
#    'mysql://ensro@mysql-ens-vertannot-staging:4573/94');


# Add in extra cores from genebuild server
# danio_rerio_core_92_11@mysql-ens-vertannot-staging:4573
# Bio::EnsEMBL::DBSQL::DBAdaptor->new(
#      -host => 'mysql-ens-vertannot-staging',
#      -user => 'ensro',
#      -port => 4573,
#      -species => 'danio_rerio',
#      -group => 'core',
#      -dbname => 'danio_rerio_core_92_11',
#  );


#-------------------------HOMOLOGY DATABASES-----------------------------------

# Individual pipeline database for ProteinTrees:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-7',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4617,
     -species => 'compara_ptrees',
     -dbname => 'muffato_protein_trees_95_grch37',
);

# Individual pipeline database for Families:
#Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-3',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4523,
#     -species => 'compara_families',
#     -dbname => 'carlac_families_94',
#);

# Individual pipeline database for ncRNAtrees:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-2',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4522,
     -species => 'compara_nctrees',
     -dbname => 'waakanni_waakanni_compara_nctrees_95_grch37',
);

# Reindexed mouse strains protein trees
#Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-1',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4485,
#     -species => 'murinae_ptrees',
#     -dbname => 'muffato_murinae_protein_trees_94',
#);

# Reindexed mouse strains ncRNA trees
#Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-1',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4485,
#     -species => 'murinae_nctrees',
#     -dbname => 'muffato_murinae_ncrna_trees_94',
#);

# ------------------------- LASTZ DATABASES: -----------------------------------

# {human, cow, sheep} v goat
#Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-vertannot-staging',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4573,
#     -species => 'goat_lastz',
#     -dbname => 'ensembl_compara_mammals',
#);


#Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-3',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4523,
#     -species => 'human_patches',
#     -dbname => 'carlac_lastz_human_patches_92',
#);

# ------------------------- EPO DATABASES: -----------------------------------

#Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-3',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4523,
#     -species => 'primates_epo',
#     -dbname => 'carlac_primates_epo_92',
#);

# -----------------------OTHER ALIGNMENTS-------------------------------

# mysql-ens-compara-prod-2.ebi.ac.uk:4522/muffato_amniotes_mercator_pecan_92
#Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-2',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4522,
#     -species => 'amniotes_pecan',
#     -dbname => 'muffato_amniotes_mercator_pecan_92',
#);

#Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-3',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4523,
#     -species => 'compara_syntenies',
#     -dbname => 'carlac_syntenies_92',
#);

# ----------------------COMPARA DATABASES---------------------------

# Compara Master database:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'compara_master',
    -dbname => 'ensembl_compara_master_grch37',
);

# previous release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'compara_prev',
    -dbname => 'ensembl_compara_94_grch37',
);

# current release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'compara_curr',
    -dbname => 'ensembl_compara_95_grch37',
);

# previous ancestral database on one of Compara servers:
#Bio::EnsEMBL::DBSQL::DBAdaptor->new(
#    -host => 'mysql-ens-compara-prod-1',
#    -user => 'ensadmin',
#    -pass => $ENV{'ENSADMIN_PSW'},
#    -port => 4523,
#    -group => 'core',
#    -species => 'ancestral_prev',
#    -dbname => 'ensembl_ancestral_93',
#);

# current ancestral database on one of Compara servers. This alias is need for the epo data dumps to work:
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-sta-2',
    -user => 'ensro',
#    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4520,
    -group => 'core',
    -species => 'ancestral_sequences',
    -dbname => 'ensembl_ancestral_95',
);

Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-sta-2',
    -user => 'ensro',
#    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4520,
    -group => 'core',
    -species => 'ancestral_curr',
    -dbname => 'ensembl_ancestral_95',
);

# ensembl production (maintained by production team):
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-sta-2',
    -user => 'ensro',
    -port => 4520,
    -species => 'ensembl_production',
    -dbname => 'ensembl_production_95',
    -group => 'production',
);

# NCBI taxonomy database (also maintained by production team):
#Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor->new(
#    -host => 'mysql-ens-sta-1.ebi.ac.uk',
#    -user => 'ensro',
#    -port => 4519,
#    -group => 'taxonomy',
#    -species => 'ncbi_taxonomy',
#    -dbname => 'ncbi_taxonomy',
#);

# # ---------------------OTHER DATABASES-----------------------------

# Members
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'compara_members',
    -dbname => 'waakanni_load_members_95_grch37',
);

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
 Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-2',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4522,
     -species => 'alt_allele_projection',
     -dbname => 'waakanni_alt_allele_import_95_grch37',
 );

1;
