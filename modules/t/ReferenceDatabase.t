#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::Registry;
use Bio::EnsEMBL::Test::MultiTestDB;

use Test::More tests => 4;
use Test::Exception;

# check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::Utils::ReferenceDatabase');

#####################################################################
##        Set up test databases and add to the registry            ##

my $test_ref_compara = Bio::EnsEMBL::Test::MultiTestDB->new( "test_ref_compara" );
my $compara_dba = $test_ref_compara->get_DBAdaptor( "compara" );

my $test_ref_human_1 = Bio::EnsEMBL::Test::MultiTestDB->new( "test_ref_human_1" );
my $human1_dba = $test_ref_human_1->get_DBAdaptor('core');
Bio::EnsEMBL::Registry->add_DBAdaptor('homo_sapiens', 'core', $human1_dba);
my $test_ref_mouse = Bio::EnsEMBL::Test::MultiTestDB->new( "test_ref_mouse" );
my $mouse_dba = $test_ref_mouse->get_DBAdaptor('core');
Bio::EnsEMBL::Registry->add_DBAdaptor('mus_musculus', 'core', $mouse_dba);
my $test_ref_wheat = Bio::EnsEMBL::Test::MultiTestDB->new( "test_ref_wheat" );
my $wheat_dba = $test_ref_wheat->get_DBAdaptor('core');
Bio::EnsEMBL::Registry->add_DBAdaptor('triticum_aestivum', 'core', $wheat_dba);

# create DBA, but don't add it to registry yet - will add it later
my $test_ref_human_2 = Bio::EnsEMBL::Test::MultiTestDB->new( "test_ref_human_2" );
my $human2_dba = $test_ref_human_2->get_DBAdaptor('core');
my $test_fake_mouse = Bio::EnsEMBL::Test::MultiTestDB->new( "test_fake_mouse" );
my $fake_mouse_dba = $test_fake_mouse->get_DBAdaptor('core');

# Save status of database prior to alteration for restoration at end of tests
$test_ref_compara->save('compara', 'genome_db');
$test_ref_compara->save('compara', 'species_set');
$test_ref_compara->save('compara', 'species_set_header');
$test_ref_compara->save('compara', 'seq_member');
$test_ref_compara->save('compara', 'gene_member');
$test_ref_compara->save('compara', 'dnafrag');

##                                                                 ##
#####################################################################

note("------------------------ update_reference_genome testing ---------------------------------");

subtest "update_reference_genome", sub {
    my ($ref_update, $components, $new_dnafrags);
    my ($human_1_gdb, $human_2_gdb, $mouse_gdb, $wheat_gdb);

    # add initial references
    ok( $ref_update = Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'homo_sapiens') );
    ( $human_1_gdb, $components, $new_dnafrags ) = @$ref_update;
    is( $human_1_gdb->name, 'homo_sapiens', 'human added successfully' );
    is( $human_1_gdb->genebuild, '2019-07', 'human genebuild correct' );
    is( $new_dnafrags, 8, 'human dnafrags added' );

    ok( $ref_update = Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'mus_musculus') );
    ( $mouse_gdb, $components, $new_dnafrags ) = @$ref_update;
    is( $mouse_gdb->name, 'mus_musculus', 'mouse added successfully' );
    is( $mouse_gdb->genebuild, '2012-07', 'mouse genebuild correct' );
    is( $new_dnafrags, 6, 'mouse dnafrags added' );

    ok( $ref_update = Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'triticum_aestivum', -TAXON_ID => 12345) );  # need fake taxon_id
    ( $wheat_gdb, $components, $new_dnafrags ) = @$ref_update;
    is( $wheat_gdb->name, 'triticum_aestivum', 'wheat added successfully' );
    is( $wheat_gdb->genebuild, '2013-12-MIPS', 'wheat genebuild correct' );
    is( $components, undef, 'no wheat genome components loaded' );
    is( $new_dnafrags, 3, 'wheat dnafrags added' );

    # replace human in registry and test adding new annotation version
    Bio::EnsEMBL::Compara::Utils::Registry::remove_species(['homo_sapiens']);
    Bio::EnsEMBL::Registry->add_DBAdaptor('homo_sapiens', 'core', $human2_dba);

    ok( $ref_update = Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'homo_sapiens') );
    ( $human_2_gdb, $components, $new_dnafrags ) = @$ref_update;
    is( $human_2_gdb->name, 'homo_sapiens', 'second human added successfully' );
    is( $human_2_gdb->genebuild, '2020-10', 'second human genebuild correct' );
    is( $new_dnafrags, 8, 'second human dnafrags added' );
    isnt($human_1_gdb->dbID, $human_2_gdb->dbID, 'both humans have different ids');

    # delete a dnafrag to test force update
    $compara_dba->dbc->do("DELETE FROM dnafrag WHERE name = '2' and genome_db_id = " . $human_2_gdb->dbID);

    # check -FORCE flag functionality
    throws_ok {
        Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'homo_sapiens')
    } qr/is already in the compara DB/, 'no update without force flag';

    my $human_3_gdb;
    ok( $ref_update = Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'homo_sapiens', -FORCE=>1) );
    ( $human_3_gdb, $components, $new_dnafrags ) = @$ref_update;
    is( $new_dnafrags, 1, '1 human dnafrag force added' );
    is($human_2_gdb->dbID, $human_3_gdb->dbID, 'no new id - updated existing genome');

    # check -STORE_COMPONENTS flag functionality
    $compara_dba->dbc->do("DELETE FROM dnafrag WHERE genome_db_id = " . $wheat_gdb->dbID);
    ok( $ref_update = Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'triticum_aestivum', -FORCE => 1, -STORE_COMPONENTS => 1) );
    ( $wheat_gdb, $components, $new_dnafrags ) = @$ref_update;
    is( $wheat_gdb->name, 'triticum_aestivum', 'wheat added successfully' );
    is( $wheat_gdb->genebuild, '2013-12-MIPS', 'wheat genebuild correct' );
    is( scalar @$components, 3, 'wheat genome components loaded successfully' );
    is( $new_dnafrags, 6, 'wheat dnafrags added' );
};

note("------------------------ remove_reference_genome testing ---------------------------------");

subtest "remove_reference_genome", sub {
    my $rat_genome_db = $compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly('rattus_norvegicus', 'RGSC3.4');
    my $rat_genome_db_id = $rat_genome_db->dbID;
    ok( Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::remove_reference_genome($compara_dba, $rat_genome_db), 'rat reference removed' );

    my ($seq_member_count) = $compara_dba->dbc->db_handle->selectrow_array("SELECT COUNT(*) FROM seq_member WHERE genome_db_id = $rat_genome_db_id");
    is( $seq_member_count, 0, 'all seq_members removed' );
    my ($gene_member_count) = $compara_dba->dbc->db_handle->selectrow_array("SELECT COUNT(*) FROM gene_member WHERE genome_db_id = $rat_genome_db_id");
    is( $gene_member_count, 0, 'all gene_members removed' );
    my ($dnafrag_count) = $compara_dba->dbc->db_handle->selectrow_array("SELECT COUNT(*) FROM dnafrag WHERE genome_db_id = $rat_genome_db_id");
    is( $dnafrag_count, 0, 'all dnafrags removed' );
};

note("------------------------ rename_reference_genome testing ---------------------------------");

subtest "rename_reference_genome", sub {
    # Add fake mouse to the registry
    Bio::EnsEMBL::Registry->add_DBAdaptor('mus_musculusus', 'core', $fake_mouse_dba);

    my $mouse_gdb = $compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly('mus_musculus', 'GRCm38');
    my $mouse_gdb_id = $mouse_gdb->dbID;
    ok( Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::rename_reference_genome($compara_dba, 'mus_musculus', 'mus_musculusus'), 'mouse reference renamed' );

    my ($gdb_name) = $compara_dba->dbc->db_handle->selectrow_array("SELECT name FROM genome_db WHERE genome_db_id = $mouse_gdb_id");
    is( $gdb_name, 'mus_musculusus', 'mus_musculus reference renamed to mus_musculusus' );
};

# Restore the databases for next tests
$test_ref_compara->restore('compara', 'genome_db');
$test_ref_compara->restore('compara', 'species_set');
$test_ref_compara->restore('compara', 'species_set_header');
$test_ref_compara->restore('compara', 'seq_member');
$test_ref_compara->restore('compara', 'gene_member');
$test_ref_compara->restore('compara', 'dnafrag');

done_testing();
