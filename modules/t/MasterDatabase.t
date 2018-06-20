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

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Test::MultiTestDB;

BEGIN {
    use Test::Most;
}

# check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::Utils::MasterDatabase'); 

#####################################################################
##        Set up test databases and add to the registry            ##

my $species = ['homo_sapiens', 'felis_catus', 'mus_musculus', 'pan_troglodytes'];

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "test_master" );
my $compara_dba = $multi->get_DBAdaptor( "compara" );
# Bio::EnsEMBL::Registry->add_DBAdaptor();

my $species_db;
my $species_db_adaptor;
## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (@$species) {
  $species_db->{$this_species} = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  die if (!$species_db->{$this_species});
  $species_db_adaptor->{$this_species} = $species_db->{$this_species}->get_DBAdaptor('core');
  Bio::EnsEMBL::Registry->add_DBAdaptor($this_species, 'core', $species_db_adaptor->{$this_species});
}
##                                                                 ##
#####################################################################

my $gdb_adaptor  = $compara_dba->get_GenomeDBAdaptor;
my $ss_adaptor   = $compara_dba->get_SpeciesSetAdaptor;
my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

#####################################################################
##             Test genome_db and dnafrag updating                 ##

my ($update, $new_gdb, $component_gdbs, $new_dnafrags);

## Test 1: adding new genome and releasing it
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'homo_sapiens', -RELEASE => 1) );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_gdb->name, 'homo_sapiens', 'homo_sapiens added successfully' );
is( $new_dnafrags, 6, 'correct number of dnafrags added' );
is( $new_gdb->assembly, 'GRCh37', 'correct assembly version loaded' );
is( $new_gdb->first_release, software_version(), 'new genome released' );


## Test 2: adding new genome and NOT releasing it
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'felis_catus', -RELEASE => 0) );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_gdb->name, 'felis_catus', 'felis_catus added successfully' );
is( $new_dnafrags, 70, 'correct number of dnafrags added' );
is( $new_gdb->assembly, 'CAT', 'correct assembly version loaded' );
is( $new_gdb->first_release, undef, 'new genome remains unreleased' );


## Test 3: force update and release
my $sth = $compara_dba->dbc->do('DELETE FROM dnafrag WHERE genome_db_id = 138 LIMIT 10');
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'felis_catus', -RELEASE => 1, -FORCE => 1) );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_gdb->name, 'felis_catus', 'felis_catus force updated' );
is( $new_gdb->first_release, software_version(), 'new genome now released' );
is( $new_dnafrags, 10, 'correct number of dnafrags added' );


## Test 4: updating assembly with offset
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'mus_musculus', -RELEASE => 1, -OFFSET => 1000) );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_gdb->name, 'mus_musculus', 'mus_musculus assembly updated successfully' );
is( $new_dnafrags, 6, 'correct number of dnafrags added' );
is( $new_gdb->dbID, 1001, 'id correctly offset' );
is( $new_gdb->first_release, software_version(), 'new assembly released' );
# check everything associated with old assembly has been retired
my $old_mouse_gdb = $gdb_adaptor->fetch_by_dbID(57);
is( $old_mouse_gdb->last_release, software_version()-1, 'old assembly retired' );
my $old_ss = $ss_adaptor->fetch_by_dbID(12345);
is( $old_ss->last_release, software_version()-1, 'old species set retired' );
my $old_mlss = $mlss_adaptor->fetch_by_dbID(123456);
is( $old_mlss->last_release, software_version()-1, 'old method link species set retired' );


## Test 5: add genome with manual taxon_id
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'pan_troglodytes', -RELEASE => 1, -TAXON_ID => 12345) );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_gdb->name, 'pan_troglodytes', 'pan_troglodytes added successfully' );
is( $new_dnafrags, 4, 'correct number of dnafrags added' );
is( $new_gdb->assembly, 'CHIMP2.1.4', 'correct assembly version loaded' );
is( $new_gdb->taxon_id, '12345', 'correct taxon_id assigned' );
is( $new_gdb->first_release, software_version(), 'new genome released' );


## Test 6: updating component genomes


##                                                                 ##
#####################################################################



#####################################################################
##                  Test collection editing                        ##

## Test 1: create a new collection
my $new_collection;
ok( $new_collection = Bio::EnsEMBL::Compara::Utils::MasterDatabase::new_collection( $compara_dba, 'test_col', ['homo_sapiens', 'pan_troglodytes'] ) );
is( $new_collection->name, 'collection-test_col', 'new collection created with correct name' );
my @gdb_ids = sort {$a <=> $b} map {$_->dbID} @{ $new_collection->genome_dbs };
is_deeply( \@gdb_ids, [137, 1002], 'correct genome dbs included' );


## Test 2: update an intermediate collection that has not been through a release yet 
## (i.e. first_release = software_version(); retirement should result in NULL first & last release)
my $updated_collection;
ok( $updated_collection = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_collection( $compara_dba, 'test_col', ['pongo_abelii', 'nomascus_leucogenys'] ) );
is( $updated_collection->name, 'collection-test_col', 'collection updated with correct name' );
@gdb_ids = sort {$a <=> $b} map {$_->dbID} @{ $updated_collection->genome_dbs };
is_deeply( \@gdb_ids, [60, 115, 137, 1002], 'correct genome dbs included' );
$new_collection = $ss_adaptor->fetch_by_dbID( $new_collection->dbID ); # re-read from db for updated release metadata
is_deeply( [$new_collection->first_release, $new_collection->last_release], [undef, undef], 'intermediate collection retired correctly' );


## Test 3: update a collection that has been released already 
## (i.e. first_release < software_version() retirement should result in NULL last_release ONLY)
ok( $updated_collection = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_collection( $compara_dba, 'update_test', ['homo_sapiens', 'pan_troglodytes', 'gorilla_gorilla'] ) );
is( $updated_collection->name, 'collection-update_test', 'collection updated with correct name' );
my $old_collection = $ss_adaptor->fetch_by_dbID( 12345 ); # re-read from db for updated release metadata
is_deeply( [$old_collection->first_release, $old_collection->last_release], [80, software_version()-1], 'old collection retired correctly' );
@gdb_ids = sort {$a <=> $b} map {$_->dbID} @{ $updated_collection->genome_dbs };
is_deeply( \@gdb_ids, [60, 115, 123, 137, 1002], 'correct genome dbs included' );

##                                                                 ##
#####################################################################

done_testing();
