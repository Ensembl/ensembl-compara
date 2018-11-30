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
#   Bio::EnsEMBL::Registry->load_registry_from_url(
#    'mysql://ensro@mysql-ens-sta-1.ebi.ac.uk:4519/95');
  Bio::EnsEMBL::Registry->load_registry_from_url(
    'mysql://ensro@mysql-ens-vertannot-staging:4573/95');


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
     -host => 'mysql-ens-compara-prod-4',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4401,
     -species => 'compara_ptrees',
     -dbname => 'mateus_protein_trees_95',
);

# Individual pipeline database for Families:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4523,
     -species => 'compara_families',
     -dbname => 'carlac_families_fix_95',
);

# Individual pipeline database for ncRNAtrees:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-2',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4522,
     -species => 'compara_nctrees',
     -dbname => 'waakanni_compara_nctrees_95',
);

# Reindexed mouse strains protein trees
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-8',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4618,
     -species => 'murinae_ptrees',
     -dbname => 'carlac_murinae_protein_trees_95',
);

# Reindexed mouse strains ncRNA trees
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-ens-compara-prod-8',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4618,
     -species => 'murinae_nctrees',
     -dbname => 'carlac_murinae_ncrna_trees_95',
);

# ------------------------- LASTZ DATABASES: -----------------------------------

# human v mammals lastz
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-2',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4522,
    -species => 'human_v_mammal_lastz',
    -dbname => 'waakanni_koala_pbear_wormbat_etc_vs_human_lastz',
);

# batch 1
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-8',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4618,
    -species => 'lastz_1',
    -dbname => 'carlac_lastz_95',
);

# batch 2
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-2',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4522,
    -species => 'lastz_2',
    -dbname => 'waakanni_lastz_95',
);

# (tick) mysql-ens-compara-prod-1 muffato_lastz_95a
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'lastz_a',
    -dbname => 'muffato_lastz_95a',
);

# (tick) mysql-ens-compara-prod-5 muffato_lastz_95b
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4615,
    -species => 'lastz_b',
    -dbname => 'muffato_lastz_95b',
);

# (tick) mysql-ens-compara-prod-7 muffato_lastz_95c
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-7',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4617,
    -species => 'lastz_c',
    -dbname => 'muffato_lastz_95c',
);

# (tick) mysql-ens-compara-prod-7 muffato_lastz_95d
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-7',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4617,
    -species => 'lastz_d',
    -dbname => 'muffato_lastz_95d',
);

# (tick) mysql-ens-compara-prod-5 muffato_lastz_95e
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4615,
    -species => 'lastz_e',
    -dbname => 'muffato_lastz_95e',
);

# ------------------------- EPO DATABASES: -----------------------------------

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'mammals_epo',
    -dbname => 'muffato_mammals_epo_95',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-3',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4523,
    -species => 'mammals_epo_low',
    -dbname => 'carlac_mammals_epo_low_coverage_95',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'sauropsids_epo',
    -dbname => 'muffato_sauropsids_epo_95',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-6',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4616,
    -species => 'sauropsids_epo_low',
    -dbname => 'carlac_sauropsids_epo_low_coverage_95',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'fish_epo',
    -dbname => 'muffato_fish_epo_95',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'fish_epo_low',
    -dbname => 'muffato_fish_epo_low_coverage_95',
);

# -----------------------OTHER ALIGNMENTS-------------------------------

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-6',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4616,
    -species => 'amniotes_pecan',
    -dbname => 'carlac_amniotes_mercator_pecan_95',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4615,
    -species => 'compara_syntenies',
    -dbname => 'carlac_synteny_95',
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
    -dbname => 'ensembl_compara_94',
);

# current release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -species => 'compara_curr',
    -dbname => 'ensembl_compara_95',
);

# previous ancestral database on one of Compara servers:
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4523,
    -group => 'core',
    -species => 'ancestral_prev',
    -dbname => 'ensembl_ancestral_94',
);

# current ancestral database on one of Compara servers. This alias is need for the epo data dumps to work:
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -group => 'core',
    -species => 'ancestral_sequences',
    -dbname => 'ensembl_ancestral_95',
);

Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -group => 'core',
    -species => 'ancestral_curr',
    -dbname => 'ensembl_ancestral_95',
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
    -host => 'mysql-ens-sta-1.ebi.ac.uk',
    -user => 'ensro',
    -port => 4519,
    -group => 'taxonomy',
    -species => 'ncbi_taxonomy',
    -dbname => 'ncbi_taxonomy',
);

# # ---------------------OTHER DATABASES-----------------------------

# Members
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-3',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4523,
    -species => 'compara_members',
    -dbname => 'carlac_load_members_95',
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
# Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#     -host => 'mysql-ens-compara-prod-1',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 4485,
#     -species => 'alt_allele_projection',
#     -dbname => 'carlac_alt_allele_import_90',
# );

1;
