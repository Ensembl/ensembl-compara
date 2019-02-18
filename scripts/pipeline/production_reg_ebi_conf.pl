#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

my $curr_release = 96;
my $prev_release = $curr_release - 1;

# ---------------------- CURRENT CORE DATABASES---------------------------------

# The majority of core databases live on staging servers:
#Bio::EnsEMBL::Registry->load_registry_from_url(
#   "mysql://ensro\@mysql-ens-sta-1.ebi.ac.uk:4519/$curr_release");
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


#------------------------COMPARA DATABASE LOCATIONS----------------------------------

# FORMAT: species/alias name => [ host, db_name ]
my $compara_dbs = {
    # general compara dbs
    'compara_master' => [ 'mysql-ens-compara-prod-1', 'ensembl_compara_master' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-1', 'ensembl_compara_96' ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-1', 'ensembl_compara_95' ],

    # homology dbs
    'compara_members'  => [ 'mysql-ens-compara-prod-6', 'mateus_ensembl_load_members_96'  ],
    'compara_ptrees'   => [ 'mysql-ens-compara-prod-1', 'mateus_ensembl_protein_trees_96' ],
    'ptrees_prev'      => [ 'mysql-ens-compara-prod-4', 'mateus_protein_trees_95' ],
    'compara_families' => [ 'mysql-ens-compara-prod-2', 'mateus_ensembl_families_96'  ],
    'compara_nctrees'  => [ 'mysql-ens-compara-prod-3', 'muffato_ensembl_compara_nctrees_96' ],
    'murinae_ptrees'   => [ 'mysql-ens-compara-prod-5', 'muffato_murinae_protein_trees_96b' ],
    'murinae_nctrees'  => [ 'mysql-ens-compara-prod-5', 'muffato_murinae_nctrees_96' ],

    # LASTZ dbs
    'lastz_batch_1'    => [ 'mysql-ens-compara-prod-1', 'mateus_lastz_ensembl_batch_1' ],
    'lastz_batch_2'  => [ 'mysql-ens-compara-prod-1', 'mateus_lastz_ensembl_batch_2' ],
    'lastz_batch_3'  => [ 'mysql-ens-compara-prod-2', 'mateus_lastz_ensembl_batch_3' ],
    'lastz_batch_4'  => [ 'mysql-ens-compara-prod-2', 'mateus_lastz_ensembl_batch_4' ],
    'lastz_batch5'   => [ 'mysql-ens-compara-prod-3', 'muffato_lastz_ensembl_batch_5_96' ],
    'lastz_batch6'   => [ 'mysql-ens-compara-prod-3', 'muffato_lastz_ensembl_batch_6_96' ],
    'lastz_batch7'   => [ 'mysql-ens-compara-prod-4', 'carlac_vertebrates_batch7_lastz_96' ],
    'lastz_batch8'   => [ 'mysql-ens-compara-prod-6', 'carlac_lastz_ensembl_batch_8' ],
    'lastz_batch_9'  => [ 'mysql-ens-compara-prod-5', 'waakanni_lastz_ensembl_batch_9' ],
    'lastz_batch_10' => [ 'mysql-ens-compara-prod-5', 'waakanni_lastz_ensembl_batch_10' ],

    # EPO dbs
    ## mammals
    'mammals_epo'         => [ 'mysql-ens-compara-prod-2', 'mateus_mammals_epo_96' ],
    'mammals_epo_prev'    => [ 'mysql-ens-compara-prod-1', 'muffato_mammals_epo_95' ],
    'mammals_epo_low'     => [ 'mysql-ens-compara-prod-3', 'muffato_mammals_epo_low_coverage_96' ],
    'mammals_epo_anchors' => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    ## sauropsids
    'sauropsids_epo'         => [ 'mysql-ens-compara-prod-4', 'carlac_sauropsids_epo_96' ],
    'sauropsids_epo_prev'    => [ 'mysql-ens-compara-prod-1', 'muffato_sauropsids_epo_95' ],
    'sauropsids_epo_low'     => [ 'mysql-ens-compara-prod-3', 'carlac_sauropsids_epo_low_coverage_96' ],
    'sauropsids_epo_anchors' => [ 'mysql-ens-compara-prod-1', 'mm14_4saur_gen_anchors_hacked_86' ],

    ## fish
    'fish_epo'         => [ 'mysql-ens-compara-prod-3', 'muffato_fish_epo_96' ],
    'fish_epo_prev'    => [ 'mysql-ens-compara-prod-1', 'muffato_fish_epo_95' ],
    'fish_epo_low'     => [ 'mysql-ens-compara-prod-3', 'muffato_fish_epo_low_coverage_96' ],
    'fish_epo_anchors' => [ 'mysql-ens-compara-prod-5', 'muffato_generate_anchors_fish_96' ],

    ## primates
    'primates_epo'         => [ 'mysql-ens-compara-prod-6', 'waakanni_primates_epo_96' ],
    'primates_epo_prev'   => [ 'mysql-ens-compara-prod-2', 'mateus_mammals_epo_96' ],      # Primates are reused from mammals of the *same release* (same anchors and subset of species)
    'primates_epo_low'     => [ 'mysql-ens-compara-prod-3', 'muffato_primates_epo_low_coverage_96' ],
    'primates_epo_anchors' => [ 'mysql-ens-compara-prod-2', 'waakanni_generate_anchors_mammals_93' ],

    # other alignments
    'amniotes_pecan'      => [ 'mysql-ens-compara-prod-5', 'muffato_amniotes_mercator_pecan_96b' ],
    'amniotes_pecan_prev' => [ 'mysql-ens-compara-prod-6', 'carlac_amniotes_mercator_pecan_95' ],

    'compara_syntenies'   => [ 'mysql-ens-compara-prod-8', 'mateus_synteny_96' ],

    # miscellaneous
    'alt_allele_projection' => [ 'mysql-ens-compara-prod-1', 'mateus_ensembl_alt_allele_import_96' ],
};

add_compara_dbs( $compara_dbs ); # NOTE: by default, '%_prev' dbs will have a read-only connection

# ----------------------NON-COMPARA DATABASES------------------------

Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'mysql-ens-compara-prod-1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 4485,
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
    -species => 'ancestral_sequences',     # FIXME: this needs to be renamed to ancestral_sequences when we run the dumps
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

    foreach my $alias_name ( keys %$compara_dbs ) {
        my ( $host, $db_name ) = @{ $compara_dbs->{$alias_name} };

        my ( $user, $pass ) = ( 'ensadmin', $ENV{'ENSADMIN_PSW'} );
        ( $user, $pass ) = ( 'ensro', '' ) if ( $alias_name =~ /_prev/ );

        Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
            -host => $host,
            -user => $user,
            -pass => $pass,
            -port => get_port($host),
            -species => $alias_name,
            -dbname  => $db_name,
        );
    }
}

sub get_port {
    my $host = shift;
    my $port = `$host port`;
    chomp $port;
    return $port;
}

1;
