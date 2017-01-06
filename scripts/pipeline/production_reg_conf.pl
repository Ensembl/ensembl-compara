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
# Bio::EnsEMBL::Registry->load_registry_from_url(
#   'mysql://ensro@ens-livemirror/85');
Bio::EnsEMBL::Registry->load_registry_from_url(
  'mysql://ensro@ens-staging1/87');
Bio::EnsEMBL::Registry->load_registry_from_url(
  'mysql://ensro@ens-staging2/87');

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
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara4',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'compara_ptrees',
     -dbname => 'wa2_protein_trees_87',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'compara_mice_ptrees',
     -dbname => 'mm14_protein_trees_mouse_86b',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'compara_mouse_strains_homologies',
     -dbname => 'mm14_mouse_strains_homologies_87',
);

# Individual pipeline database for ncRNAtrees:
 Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'compara_nctrees',
     -dbname => 'mp14_compara_nctrees_87',
 );

 Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'compara_mouse_nctrees',
     -dbname => 'mm14_nctrees_mouse_86',
);

# # Individual pipeline database for Families:
 Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara2',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'compara_families',
     -dbname => 'cc21_ensembl_families_87',
);

# ------------------------- LASTZ DATABASES: -----------------------------------

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'mmul_mmur_lastz',
     -dbname => 'cc21_hsap_mmul_mmur_lastz_86',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara2',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'ggal_lastz_1',
     -dbname => 'mp14_LASTZ_chicken_col1_86',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara4',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'ggal_lastz_2',
     -dbname => 'wa2_chicken_lastz_86',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'ggal_lastz_3',
     -dbname => 'mm14_LASTZ_chicken_col3_86',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'hsap_ggal_lastz',
     -dbname => 'cc21_human_chicken_lastz_86',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'mmus_ggal_lastz',
     -dbname => 'cc21_mouse_chicken_lastz_86',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara4',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'hsap_mspr_lastz',
     -dbname => 'mp14_LASTZ_human_spretus_86',
);

# ------------------------- EPO DATABASES: -----------------------------------

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'mammal_epo',
     -dbname => 'cc21_mammals_epo_pt3_86',
);

Bio::EnsEMBL::DBSQL::DBAdaptor->new(
     -host => 'compara4',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'mammal_ancestral_epo',
     -dbname => 'cc21_mammals_ancestral_core_86',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara5',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'primates_epo',
     -dbname => 'wa2_primates_epo',
);

Bio::EnsEMBL::DBSQL::DBAdaptor->new(
     -host => 'compara4',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'primates_ancestral_epo',
     -dbname => 'wa2_primates_ancestral_core_85',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'birds_epo',
     -dbname => 'mm14_4sauropsids_new4sauranchor_hacked_86_epo',
);

Bio::EnsEMBL::DBSQL::DBAdaptor->new(
     -host => 'compara1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'birds_ancestral_epo',
     -dbname => 'mm14_4sauropsids_new4sauranchor_hacked_86_ancestral_core_86',
);

# -----------------------OTHER ALIGNMENTS-------------------------------

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'pecan',
     -dbname => 'mm14_pecan_24way_86b',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'mammal_epo2x',
     -dbname => 'cc21_EPO_low_86',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara1',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'bird_epo2x',
     -dbname => 'mm14_EPO_low_86',
);

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'compara3',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 3306,
     -species => 'synteny',
     -dbname => 'cc21_synteny_86',
);

# ----------------------------------------------------------------------

# Merged homologies
Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(
    # eHive DBAdaptor only accepts a URL
     -url  => 'mysql://ensadmin:'.$ENV{'ENSADMIN_PSW'}.'@compara1:3306/mm14_pipeline_hom_final_merge_86',
     -species => 'homologies_merged',
     -no_sql_schema_version_check => 1,
);

# Compara Master database:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_master',
    -dbname => 'mm14_ensembl_compara_master',
);

# previous release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
#    -host => 'ens-livemirror',
    -host => 'compara5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_prev',
    -dbname => 'cc21_ensembl_compara_86',
);

# current release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_curr',
    -dbname => 'mp14_ensembl_compara_87',
);

# previous ancestral database on one of Compara servers:
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'compara5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'ancestral_prev',
    -dbname => 'cc21_ensembl_ancestral_86',
);

# current ancestral database on one of Compara servers:
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'compara5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'ancestral_curr',
    -dbname => 'mp14_ensembl_ancestral_87',
);

# ensembl production (maintained by production team):
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'ens-staging',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'ensembl_production',
    -dbname => 'ensembl_production',
    -group => 'production',
);

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor->new(
    -host => 'ens-livemirror',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -group => 'taxonomy',
    -species => 'ncbi_taxonomy',
    -dbname => 'ncbi_taxonomy',
);

# # final compara on staging:
# Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( ## HAS TO BE CREATED (FINAL DB)
#     -host => 'ens-staging',
#     -user => 'ensadmin',
#     -pass => $ENV{'ENSADMIN_PSW'},
#     -port => 3306,
#     -species => 'compara_staging',
#     -dbname => 'ensembl_compara_86',
# );


1;
