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

my $curr_release = 98;
my $prev_release = $curr_release - 1;

# ---------------------- CURRENT CORE DATABASES----------------------------------

# most cores are on EG servers, but some are on ensembl's vertannot-staging
Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");
#Bio::EnsEMBL::Registry->load_registry_from_url("mysql://ensro\@mysql-ens-sta-3:4160/$curr_release");
#Bio::EnsEMBL::Registry->remove_DBAdaptor('saccharomyces_cerevisiae', 'core'); # never use EG's version of yeast

# ---------------------- PREVIOUS CORE DATABASES---------------------------------

# previous release core databases will be required by LoadMembers only
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
    'compara_master' => [ 'mysql-ens-compara-prod-5', 'ensembl_compara_master_plants' ],
    'compara_curr'   => [ 'mysql-ens-compara-prod-5', 'ensembl_compara_plants_45_98' ],
    'compara_prev'   => [ 'mysql-ens-compara-prod-5', 'ensembl_compara_plants_44_97' ],
    'compara_old'    => [ 'mysql-ens-compara-prod-5', 'ensembl_compara_plants_43_96' ],

    # homology dbs
    'compara_members'  => [ 'mysql-ens-compara-prod-6', 'jalvarez_plants_load_members_98'  ],
    'compara_ptrees'   => [ 'mysql-ens-compara-prod-3', 'jalvarez_default_plants_protein_trees_98' ],
    'ptrees_prev'      => [ 'mysql-ens-compara-prod-5', 'mateus_default_plants_protein_trees_97' ],

    # LASTZ dbs
    'lastz' => [ 'mysql-ens-compara-prod-2', 'jalvarez_plants_lastz_98' ],

    # synteny
    'compara_syntenies' => [ 'mysql-ens-compara-prod-8', 'jalvarez_plants_synteny_98' ],
    'compara_syntenies_9265' => [ 'mysql-ens-compara-prod-6', 'jalvarez_synteny_rerun_9265_98' ],
    'compara_syntenies_9267' => [ 'mysql-ens-compara-prod-6', 'jalvarez_synteny_rerun_9267_98' ],
};

add_compara_dbs( $compara_dbs ); # NOTE: by default, '%_prev' dbs will have a read-only connection

# ----------------------NON-COMPARA DATABASES------------------------

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor->new(
    -host => 'mysql-ens-sta-1',
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
