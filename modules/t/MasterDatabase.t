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

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Test::MultiTestDB;

BEGIN {
    use Test::Most;
}

# check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::Utils::MasterDatabase'); 

#####################################################################
##        Set up test databases and add to the registry            ##

my $species = ['homo_sapiens', 'felis_catus', 'mus_musculus', 'pan_troglodytes', 'triticum_aestivum'];

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "test_master" );
my $compara_dba = $multi->get_DBAdaptor( "compara" );
# Bio::EnsEMBL::Registry->add_DBAdaptor('test_master', 'compara', $compara_dba);

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
my $meth_adaptor = $compara_dba->get_MethodAdaptor;
my $v = software_version();

#####################################################################
##             Test genome_db and dnafrag updating                 ##

note("------------------------ genome_db testing ---------------------------------");

my ($update, $new_gdb, $component_gdbs, $new_dnafrags);

## Test 1: adding new genome and releasing it
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'homo_sapiens', -RELEASE => 1) );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_gdb->name, 'homo_sapiens', 'homo_sapiens added successfully' );
is( $new_dnafrags, 6, 'correct number of dnafrags added' );
is( $new_gdb->assembly, 'GRCh37', 'correct assembly version loaded' );
is( $new_gdb->first_release, $v, 'new genome released' );
is_deeply( $component_gdbs, [], 'no components added for human' );


## Test 2: adding new genome and NOT releasing it
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'felis_catus') );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_gdb->name, 'felis_catus', 'felis_catus added successfully' );
is( $new_dnafrags, 70, 'correct number of dnafrags added' );
is( $new_gdb->assembly, 'CAT', 'correct assembly version loaded' );
is( $new_gdb->first_release, undef, 'new genome remains unreleased' );
is_deeply( $component_gdbs, [], 'no components added for cat' );


## Test 3: force update and release
my $sth = $compara_dba->dbc->do('DELETE FROM dnafrag WHERE genome_db_id = 142 LIMIT 10');
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'felis_catus', -RELEASE => 1, -FORCE => 1) );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_gdb->name, 'felis_catus', 'felis_catus force updated' );
is( $new_gdb->first_release, $v, 'new genome now released' );
is( $new_dnafrags, 10, 'correct number of dnafrags added' );


## Test 4: updating assembly with offset
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'mus_musculus', -RELEASE => 1, -OFFSET => 1000) );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_gdb->name, 'mus_musculus', 'mus_musculus assembly updated successfully' );
is( $new_dnafrags, 6, 'correct number of dnafrags added' );
is( $new_gdb->dbID, 1001, 'id correctly offset' );
is( $new_gdb->first_release, $v, 'new assembly released' );
# check everything associated with old assembly has been retired
my $old_mouse_gdb = $gdb_adaptor->fetch_by_dbID(57);
is( $old_mouse_gdb->last_release, $v-1, 'old assembly retired' );
my $old_ss = $ss_adaptor->fetch_by_dbID(12345);
is( $old_ss->last_release, $v-1, 'old species set retired' );
my $old_mlss = $mlss_adaptor->fetch_by_dbID(123456);
is( $old_mlss->last_release, $v-1, 'old method link species set retired' );
is_deeply( $component_gdbs, [], 'no components detected for mouse' );

## Test 5: add genome with manual taxon_id
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'pan_troglodytes', -RELEASE => 0, -TAXON_ID => 12345) );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_gdb->name, 'pan_troglodytes', 'pan_troglodytes added successfully' );
is( $new_dnafrags, 4, 'correct number of dnafrags added' );
is( $new_gdb->assembly, 'CHIMP2.1.4', 'correct assembly version loaded' );
is( $new_gdb->taxon_id, '12345', 'correct taxon_id assigned' );
is( $new_gdb->first_release, undef, 'new genome unreleased' );
is_deeply( $component_gdbs, [], 'no components detected for chimp' );

## Test 6: update component genomes
my $old_wheat_gdb = $gdb_adaptor->fetch_by_dbID(137);
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'triticum_aestivum', -TAXON_ID => 12345 ) );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_gdb->name, 'triticum_aestivum', 'triticum_aestivum added successfully' );
is( $new_dnafrags, 6, 'correct number of dnafrags added' );
is( $new_gdb->assembly, 'IWGSC2', 'correct assembly version loaded' );
is( $new_gdb->first_release, undef, 'principal genome is unreleased' ); # correct default behaviour if -RELEASE is not specified
# check components
my $num_comps = scalar @$component_gdbs;
is($num_comps, 3, '3 component genome_dbs added' );
my @comp_names = sort map {$_->genome_component} @$component_gdbs;
is_deeply( \@comp_names, ['A', 'B', 'D'], 'component names correct' );
my @comp_release = map {$_->first_release} @$component_gdbs;
is_deeply( \@comp_release, [undef, undef, undef], 'components are unreleased' );


## Test 7: force release of wheat + components
ok( $update = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($compara_dba, 'triticum_aestivum', -FORCE => 1, -RELEASE => 1 ) );
( $new_gdb, $component_gdbs, $new_dnafrags ) = @$update;
is( $new_dnafrags, 0, 'correct number of dnafrags added' );
is( $new_gdb->first_release, $v, 'principal genome is now released' );
is( $old_wheat_gdb->last_release, $v-1, 'old principal genome retired' );
# check components
@comp_release = map {$_->first_release} @$component_gdbs;
is_deeply( \@comp_release, [$v, $v, $v], 'components now released' );
my @old_comp_release = map {$_->last_release} @{ $old_wheat_gdb->component_genome_dbs };
is_deeply( \@old_comp_release, [$v-1, $v-1, $v-1], 'old components retired' );

##                                                                 ##
#####################################################################

#####################################################################
##                     Test mlss editing                           ##
note("---------------------- mlss testing -------------------------------");

my $human_gdb = $gdb_adaptor->fetch_by_name_assembly('homo_sapiens');
my $cat_gdb   = $gdb_adaptor->fetch_by_name_assembly('felis_catus');
my $mouse_gdb = $gdb_adaptor->fetch_by_name_assembly('mus_musculus');
my $chimp_gdb = $gdb_adaptor->fetch_by_name_assembly('pan_troglodytes');

my $meth_epo    = $meth_adaptor->fetch_by_type('EPO');
my $meth_epo2x  = $meth_adaptor->fetch_by_type('EPO_LOW_COVERAGE');

# test 1: create, store and release new mlss
my $test_species_set;
my $test_mlss;
ok( $test_species_set = Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_species_set( [$human_gdb, $cat_gdb, $mouse_gdb], 'test_set' ), 'created test species_set' );
is( $test_species_set->name, 'test_set', 'correct name' );
is( $test_species_set->size, 3, 'correct size' );
ok( $test_mlss = Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_mlss($meth_epo, $test_species_set), 'created test mlss' );
ok( $mlss_adaptor->store($test_mlss), 'mlss stored successfully' );
$mlss_adaptor->make_object_current($test_mlss);
is( $test_mlss->is_current, '1', 'mlss made current' );
print $test_mlss->toString . "\n\n";

# test 2: create, store and release new mlss with the same name but a different method
my $test_species_set_2;
my $test_mlss_2;
ok( $test_species_set_2 = Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_species_set( [$human_gdb, $cat_gdb, $chimp_gdb], 'test_set' ), 'new test_set created' );
is( $test_species_set_2->name, 'test_set', 'correct name' );
is( $test_species_set_2->size, 3, 'correct size' );
ok( $test_mlss_2 = Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_mlss($meth_epo2x, $test_species_set_2), 'created another test mlss' );
ok( $mlss_adaptor->store($test_mlss_2), 'new mlss stored successfully' );
$mlss_adaptor->make_object_current($test_mlss_2);
is( $test_mlss->is_current, 1, 'old mlss still current' );
is( $test_mlss_2->is_current, 1, 'new mlss made current' );
print $test_mlss->toString . "\n";
print $test_mlss_2->toString . "\n\n";

# test 3: create, store and release new mlss WITH retirement of superseded mlsss, regardless of the content (doesn't have to be a superset)
my $test_species_set_3;
my $test_mlss_3;
ok( $test_species_set_3 = Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_species_set( [$human_gdb, $cat_gdb, $chimp_gdb], 'test_set' ), 'test_set created' );
is( $test_species_set_3->name, 'test_set', 'correct name' );
is( $test_species_set_3->size, 3, 'correct size' );
ok( $test_mlss_3 = Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_mlss($meth_epo, $test_species_set_3), 'created another test mlss' );
ok( $mlss_adaptor->store($test_mlss_3), 'new mlss stored successfully' );
$mlss_adaptor->make_object_current($test_mlss_3);
is( $test_mlss->is_current, 0, 'old mlss is retired' );
is( $test_mlss_3->is_current, 1, 'new mlss is current' );
print $test_mlss->toString . "\n";
print $test_mlss_2->toString . "\n";
print $test_mlss_3->toString . "\n\n";

##                                                                 ##
#####################################################################

#####################################################################
##                  Test collection editing                        ##

note("------------------------ collection testing ---------------------------------");

## Test 1: create a new collection
my $new_collection;
ok( $new_collection = Bio::EnsEMBL::Compara::Utils::MasterDatabase::new_collection( $compara_dba, 'test_col', ['homo_sapiens', 'pan_troglodytes'] ) );
is( $new_collection->name, 'collection-test_col', 'new collection created with correct name' );
my @gdb_ids = sort {$a <=> $b} map {$_->dbID} @{ $new_collection->genome_dbs };
is_deeply( \@gdb_ids, [141, 1002], 'correct genome dbs included' );
is( $new_collection->first_release, undef, 'collection is unreleased' );

## Test 2: create a new collection WITH components
ok( $new_collection = Bio::EnsEMBL::Compara::Utils::MasterDatabase::new_collection( $compara_dba, 'test_comp_col', ['homo_sapiens', 'triticum_aestivum'] ) );
is( $new_collection->name, 'collection-test_comp_col', 'new collection created with correct name' );
@gdb_ids = sort {$a <=> $b} map {$_->dbID} @{ $new_collection->genome_dbs };
is_deeply( \@gdb_ids, [141, 1003], 'correct genome dbs included' );
is( $new_collection->first_release, undef, 'collection is unreleased' );


## Test 3: update an intermediate collection that has not been through a release yet 
## (i.e. first_release = software_version(); retirement should result in NULL first & last release)
my $updated_collection;
ok( $updated_collection = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_collection( $compara_dba, 'test_col', ['pongo_abelii', 'nomascus_leucogenys'], -RELEASE => 1 ) );
is( $updated_collection->name, 'collection-test_col', 'collection updated with correct name' );
@gdb_ids = sort {$a <=> $b} map {$_->dbID} @{ $updated_collection->genome_dbs };
is_deeply( \@gdb_ids, [60, 115, 141, 1002], 'correct genome dbs included' );
$new_collection = $ss_adaptor->fetch_by_dbID( $new_collection->dbID ); # re-read from db for updated release metadata
is_deeply( [$new_collection->first_release, $new_collection->last_release], [undef, undef], 'intermediate collection retired correctly' );
is_deeply( [$updated_collection->first_release, $updated_collection->last_release], [$v, undef], 'updated collection released' );

## Test 4: update a collection that has been released already - check retirement
ok( $updated_collection = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_collection( $compara_dba, 'update_test', ['homo_sapiens', 'pan_troglodytes', 'gorilla_gorilla'], -RELEASE => 1 ) );
is( $updated_collection->name, 'collection-update_test', 'collection updated with correct name' );
my $old_collection = $ss_adaptor->fetch_by_dbID( 12345 ); # re-read from db for updated release metadata
is_deeply( [$old_collection->first_release, $old_collection->last_release], [80, $v-1], 'old collection retired correctly' );
is_deeply( [$updated_collection->first_release, $updated_collection->last_release], [$v, undef], 'updated collection released' );
@gdb_ids = sort {$a <=> $b} map {$_->dbID} @{ $updated_collection->genome_dbs };
is_deeply( \@gdb_ids, [60, 115, 123, 141, 1002], 'correct genome dbs included' );

##                                                                 ##
#####################################################################



done_testing();
