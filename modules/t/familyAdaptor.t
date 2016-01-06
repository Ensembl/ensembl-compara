#!/usr/bin/env perl
# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

use Test::More;
use Test::Exception;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils qw(debug test_getter_setter);

my $ref_species = "homo_sapiens";
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");

my $hs_dba = $homo_sapiens->get_DBAdaptor('core');
my $compara_dba = $multi->get_DBAdaptor('compara');

my $human_assembly = $hs_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;

my $gdba = $compara_dba->get_GenomeDBAdaptor;

my $hs_gdb = $gdba->fetch_by_name_assembly("homo_sapiens",$human_assembly);
$hs_gdb->db_adaptor($hs_dba);

my $ma = $compara_dba->get_SeqMemberAdaptor;
my $fa = $compara_dba->get_FamilyAdaptor;
my $mlssa = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

my $source = "ENSEMBLGENE";

is($source, 'ENSEMBLGENE');

=pod

my ($family_id, $family_stable_id, $family_description, $family_method_link_species_set_id,
    $stable_id) = $compara_dba->dbc->db_handle->selectrow_array("
        SELECT family_id, family.stable_id, family.description,
          method_link_species_set_id, member.stable_id
        FROM family LEFT JOIN family_member USING (family_id)
          LEFT JOIN member USING (member_id) LEFT JOIN genome_db USING (genome_db_id)
        WHERE source_name = '$source' AND genome_db.name = 'homo_sapiens' LIMIT 1");

subtest "Test fetch methods", sub {

    ok(1);

    my $member = $ma->fetch_by_source_stable_id($source,$stable_id);

    ok($member);

    my $families = $fa->fetch_all_by_Member($member);

    ok($families);
    ok (scalar @{$families} == 1);
    
    $families = $fa->fetch_all_by_Member_method_link_type($member,"FAMILY");
    
    $families = $fa->fetch_by_Member_source_stable_id($source,$stable_id);
    
    ok($families);
    ok (scalar @{$families} == 1);
    
    my $family = $families->[0];
    
    isa_ok( $family, "Bio::EnsEMBL::Compara::DBSQL::Family" );
    is( $family->dbID, $family_id );
    is( $family->stable_id, $family_stable_id );
    is( $family->description, $family_description );
    is( $family->method_link_species_set_id, $family_method_link_species_set_id );
    is( $family->method_link_type, "FAMILY" );
    isa_ok( $family->adaptor, "Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor", "check adaptor" );

    $multi->hide('compara', 'family');
    $multi->hide('compara', 'family_member');
    $multi->hide('compara', 'method_link_species_set');
    
    $family->{'_dbID'} = undef;
    $family->{'_adaptor'} = undef;
    $family->{'_method_link_species_set_id'} = undef;
    
    $fa->store($family);

    my $sth = $compara_dba->dbc->prepare('SELECT family_id
                                FROM family
                                WHERE family_id = ?');
    
    $sth->execute($family->dbID);
    
    ok($family->dbID && ($family->adaptor == $fa));
    debug("family->dbID = " . $family->dbID);
    
    my ($id) = $sth->fetchrow_array;
    $sth->finish;
    
    ok($id && $id == $family->dbID);
    debug("[$id] == [" . $family->dbID . "]?");
    
    $multi->restore('compara', 'family');
    $multi->restore('compara', 'family_member');
    $multi->restore('compara', 'method_link_species_set');


    done_testing();
};

=cut
done_testing();
