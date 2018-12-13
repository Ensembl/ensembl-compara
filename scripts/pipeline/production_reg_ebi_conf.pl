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

my $curr_release = 95;
my $prev_release = $curr_release - 1;

# ---------------------- CURRENT CORE DATABASES---------------------------------

# The majority of core databases live on staging servers:
  # Bio::EnsEMBL::Registry->load_registry_from_url(
  #  "mysql://ensro\@mysql-ens-sta-1.ebi.ac.uk:4519/$curr_release");
  Bio::EnsEMBL::Registry->load_registry_from_url(
    "mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");


# Add in extra cores from genebuild server
# Bio::EnsEMBL::DBSQL::DBAdaptor->new(
#      -host => 'mysql-ens-vertannot-staging',
#      -user => 'ensro',
#      -port => 4573,
#      -species => 'danio_rerio',
#      -group => 'core',
#      -dbname => 'danio_rerio_core_92_11',
#  );

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will ONLY be required by:
#   * LoadMembers_conf
#   * MercatorPecan_conf
# !!! COMMENT THIS SECTION OUT FOR ALL OTHER PIPELINES (for speed) !!!

my $suffix_separator = '__cut_here__';
Bio::EnsEMBL::Registry->load_registry_from_db(
    -host           => 'mysql-ensembl-mirror',
    -port           => 4240,
    -user           => 'ensro',
    -pass           => '',
    -db_version     => $prev_release,
    -species_suffix => $suffix_separator.$prev_release,
);


#------------------------DATABASE LOCATIONS----------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-1', 'ensembl_compara_master' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-1', 'ensembl_compara_95' ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-1', 'ensembl_compara_94' ],

    # homology dbs
    'compara_members'  => [ 'mysql-ens-compara-prod-3', 'carlac_load_members_95'  ],
    'compara_ptrees'   => [ 'mysql-ens-compara-prod-4', 'mateus_protein_trees_95' ],
    'ptrees_prev'      => [ 'mysql-ens-compara-prod-4', 'mateus_protein_trees_94' ], 
    'compara_families' => [ 'mysql-ens-compara-prod-3', 'carlac_families_fix_95'  ],
    'compara_nctrees'  => [ 'mysql-ens-compara-prod-2', 'waakanni_compara_nctrees_95' ],
    'murinae_ptrees'   => [ 'mysql-ens-compara-prod-8', 'carlac_murinae_protein_trees_95' ],
    'murinae_nctrees'  => [ 'mysql-ens-compara-prod-8', 'carlac_murinae_ncrna_trees_95' ],

    # LASTZ dbs
    'human_v_mammal_lastz' => [ 'mysql-ens-compara-prod-2', 'waakanni_koala_pbear_wormbat_etc_vs_human_lastz' ],
    'lastz_1' => [ 'mysql-ens-compara-prod-8', 'carlac_lastz_95'   ],
    'lastz_2' => [ 'mysql-ens-compara-prod-2', 'waakanni_lastz_95' ],
    'lastz_a' => [ 'mysql-ens-compara-prod-1', 'muffato_lastz_95a' ],
    'lastz_b' => [ 'mysql-ens-compara-prod-5', 'muffato_lastz_95b' ],
    'lastz_c' => [ 'mysql-ens-compara-prod-7', 'muffato_lastz_95c' ],
    'lastz_d' => [ 'mysql-ens-compara-prod-7', 'muffato_lastz_95d' ],
    'lastz_e' => [ 'mysql-ens-compara-prod-5', 'muffato_lastz_95e' ],

    # EPO dbs
    ## mammals
    'mammals_epo'         => [ 'mysql-ens-compara-prod-1', 'muffato_mammals_epo_95' ],
    'mammals_epo_prev'    => [ 'mysql-ens-compara-prod-4', 'mateus_mammals_epo_94'  ],
    'mammals_epo_low'     => [ 'mysql-ens-compara-prod-3', 'carlac_mammals_epo_low_coverage_95' ],
    'mammals_epo_anchors' => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],
    ## sauropsids
    'sauropsids_epo'         => [ 'mysql-ens-compara-prod-1', 'muffato_sauropsids_epo_95' ],
    'sauropsids_epo_prev'    => [ 'mysql-ens-compara-prod-2', 'muffato_sauropsids_epo_94_500_50'  ],
    'sauropsids_epo_low'     => [ 'mysql-ens-compara-prod-3', 'carlac_sauropsids_epo_low_coverage_95' ],
    'sauropsids_epo_anchors' => [ 'mysql-ens-compara-prod-1', 'mm14_4saur_gen_anchors_hacked_86' ],
    ## fish
    'fish_epo'         => [ 'mysql-ens-compara-prod-1', 'muffato_fish_epo_95' ],
    'fish_epo_prev'    => [ 'mysql-ens-compara-prod-3', 'carlac_fish_epo_94' ],
    'fish_epo_low'     => [ 'mysql-ens-compara-prod-1', 'muffato_fish_epo_low_coverage_95' ],
    'fish_epo_anchors' => [ 'mysql-ens-compara-prod-5', 'muffato_generate_anchors_fish_94b' ],
    ## primates
    'primates_epo'         => [ 'mysql-ens-compara-prod-1', 'muffato_primates_epo_94' ],
    'primates_epo_prev'    => [ 'mysql-ens-compara-prod-3', 'carlac_primates_epo_92b' ],
    'primates_epo_low'     => [ 'mysql-ens-compara-prod-1', 'muffato_primates_epo_low_coverage_94' ],
    'primates_epo_anchors' => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    # other alignments
    'amniotes_pecan'    => [ 'mysql-ens-compara-prod-6', 'carlac_amniotes_mercator_pecan_95' ],
    'pecan_prev'        => [ 'mysql-ens-compara-prod-2', 'mateus_amniotes_mercator_pecan_93' ],
    'compara_syntenies' => [ 'mysql-ens-compara-prod-5', 'carlac_synteny_95' ],

    # miscellaneous
    'alt_allele_projection' => [ 'mysql-ens-compara-prod-6', 'carlac_alt_allele_import_95' ],
};

add_compara_dbs( $compara_dbs ); # NOTE: by default, '%_prev' dbs will have a read-only connection

# ----------------------NON-COMPARA DATABASES------------------------

Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4523,
    -group => 'core',
    -species => 'ancestral_prev',
    -dbname => "ensembl_ancestral_$prev_release",
);

# this alias is need for the epo data dumps to work:
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -group => 'core',
    -species => 'ancestral_sequences',
    -dbname => "ensembl_ancestral_$curr_release",
);

Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
    -group => 'core',
    -species => 'ancestral_curr',
    -dbname => "ensembl_ancestral_$curr_release",
);

# ensembl production (maintained by production team):
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-sta-1',
    -user => 'ensro',
    -port => 4519,
    -species => 'ensembl_production',
    -dbname => "ensembl_production_$curr_release",
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

# -------------------------------------------------------------------

sub add_compara_dbs {
    my $compara_dbs = shift;
    my %ports = (
        'mysql-ens-compara-prod-1' => 4485,
        'mysql-ens-compara-prod-2' => 4522,
        'mysql-ens-compara-prod-3' => 4523,
        'mysql-ens-compara-prod-4' => 4401,
        'mysql-ens-compara-prod-5' => 4615,
        'mysql-ens-compara-prod-6' => 4616,
        'mysql-ens-compara-prod-7' => 4617,
        'mysql-ens-compara-prod-8' => 4618,
    );

    foreach my $alias_name ( keys %$compara_dbs ) {
        my ( $host, $db_name ) = @{ $compara_dbs->{$alias_name} };

        my ( $user, $pass ) = ( 'ensadmin', $ENV{'ENSADMIN_PSW'} );
        ( $user, $pass ) = ( 'ensro', '' ) if ( $alias_name =~ /_prev/ );

        Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
            -host => $host,
            -user => $user,
            -pass => $pass,
            -port => $ports{$host},
            -species => $alias_name,
            -dbname  => $db_name,
        );
    }
}

1;
