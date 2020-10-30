#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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

use Test::More tests => 3;
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

# create DBA, but don't add it to registry yet - will add it later
my $test_ref_human_2 = Bio::EnsEMBL::Test::MultiTestDB->new( "test_ref_human_2" );
my $human2_dba = $test_ref_human_2->get_DBAdaptor('core');

##                                                                 ##
#####################################################################

note("------------------------ update_reference_genome testing ---------------------------------");

subtest "update_reference_genome", sub {
    my ($ref_update, $components, $new_dnafrags);
    my ($human_1_gdb, $human_2_gdb, $mouse_gdb);

    # add initial references
    ok( $ref_update = Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'homo_sapiens') );
    ( $human_1_gdb, $components, $new_dnafrags ) = @$ref_update;
    is( $human_1_gdb->name, 'homo_sapiens', 'human added successfully' );
    is( $human_1_gdb->genebuild, '2019-07', 'human genebuild correct' );
    is( $new_dnafrags, 6, 'human dnafrags added' );

    ok( $ref_update = Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'mus_musculus') );
    ( $mouse_gdb, $components, $new_dnafrags ) = @$ref_update;
    is( $mouse_gdb->name, 'mus_musculus', 'mouse added successfully' );
    is( $mouse_gdb->genebuild, '2012-07', 'mouse genebuild correct' );
    is( $new_dnafrags, 6, 'mouse dnafrags added' );

    # replace human in registry and test adding new annotation version
    Bio::EnsEMBL::Compara::Utils::Registry::remove_species(['homo_sapiens']);
    Bio::EnsEMBL::Registry->add_DBAdaptor('homo_sapiens', 'core', $human2_dba);

    ok( $ref_update = Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'homo_sapiens') );
    ( $human_2_gdb, $components, $new_dnafrags ) = @$ref_update;
    is( $human_2_gdb->name, 'homo_sapiens', 'second human added successfully' );
    is( $human_2_gdb->genebuild, '2020-10', 'second human genebuild correct' );
    is( $new_dnafrags, 6, 'second human dnafrags added' );
    isnt($human_1_gdb->dbID, $human_2_gdb->dbID, 'both humans have different ids');

    # delete a dnafrag to test force update
    $compara_dba->dbc->do("DELETE FROM dnafrag WHERE name = '2' and genome_db_id = 143");

    # check -FORCE flag functionality
    throws_ok {
        Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'homo_sapiens')
    } qr/is already in the compara DB/, 'no update without force flag';

    my $human_3_gdb;
    ok( $ref_update = Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($compara_dba, 'homo_sapiens', -FORCE=>1) );
    ( $human_3_gdb, $components, $new_dnafrags ) = @$ref_update;
    is( $new_dnafrags, 1, '1 human dnafrag force added' );
    is($human_2_gdb->dbID, $human_3_gdb->dbID, 'no new id - updated existing genome');
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

done_testing();
