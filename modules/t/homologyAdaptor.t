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

use Test::More;
use Test::Exception;

use Bio::EnsEMBL::Test::MultiTestDB;

my $ref_species = "homo_sapiens";
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");

my $hs_dba = $homo_sapiens->get_DBAdaptor('core');
my $compara_dba = $multi->get_DBAdaptor('compara');

my $human_assembly = $hs_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;

my $gdba = $compara_dba->get_GenomeDBAdaptor;

my $hs_gdb = $gdba->fetch_by_name_assembly($ref_species,$human_assembly);
$hs_gdb->db_adaptor($hs_dba);

is($ref_species, 'homo_sapiens');

=pod

my $ma = $compara_dba->get_MemberAdaptor;
my $ha = $compara_dba->get_HomologyAdaptor;
my $mlssa = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

my $member_stable_id = $compara_dba->dbc->db_handle->selectrow_array("SELECT m1.stable_id
        FROM genome_db gdb1
          LEFT JOIN member m1 USING (genome_db_id)
          LEFT JOIN homology_member hm1 USING (member_id)
          LEFT JOIN homology using (homology_id)
          LEFT JOIN homology_member hm2 using (homology_id)
          LEFT JOIN member m2 on (hm2.member_id = m2.member_id)
          LEFT JOIN genome_db gdb2 on (m2.genome_db_id = gdb2.genome_db_id)
        WHERE gdb1.name = 'homo_sapiens' and gdb2.name = 'rattus_norvegicus' LIMIT 1");
my $method_link_type = "ENSEMBL_ORTHOLOGUES";

subtest "Test fetch methods", sub {

    ok(1);

    my $member = $ma->fetch_by_stable_id($member_stable_id);

    ok($member);
    
    my $homologies = $ha->fetch_all_by_Member($member);
    
    ok($homologies);
    
    $homologies = $ha->fetch_all_by_Member_method_link_type($member,"$method_link_type");

    #print STDERR "nb of homology: ", scalar @{$homology},"\n";
    
    my ($homology_id, $stable_id, $method_link_species_set_id, $description,
        $subtype, $dn, $ds, $n, $s, $lnl, $threshold_on_ds) =
          $compara_dba->dbc->db_handle->selectrow_array("SELECT homology.*
        FROM homology_member hm1
          LEFT JOIN homology using (homology_id)
          LEFT JOIN homology_member hm2 using (homology_id)
          LEFT JOIN member m2 on (hm2.member_id = m2.member_id)
          LEFT JOIN genome_db gdb on (m2.genome_db_id = gdb.genome_db_id)
        WHERE hm1.member_id = ".$member->dbID." and gdb.name = 'Rattus norvegicus'");

    my $homology = $ha->fetch_all_by_Member($member, -TARGET_SPECIES=>"Rattus norvegicus")->[0];
    
    ok( $homology );
    ok( $homology->dbID, $homology_id );
    ok( $homology->stable_id, $stable_id );
    ok( $homology->description, $description );
    ok( $homology->subtype, $subtype );
    ok( $homology->method_link_species_set_id, $method_link_species_set_id );
    ok( $homology->method_link_type, "$method_link_type" );
    ok( $homology->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor") );
    
    $multi->hide('compara', 'homology');
    $multi->hide('compara', 'homology_member');
    $multi->hide('compara', 'method_link_species_set');
    
    $homology->{'_dbID'} = undef;
    $homology->{'_adaptor'} = undef;
    $homology->{'_method_link_species_set_id'} = undef;
    
    $ha->store($homology);
    
    my $sth = $compara_dba->dbc->prepare('SELECT homology_id
                                FROM homology
                                WHERE homology_id = ?');
    
    $sth->execute($homology->dbID);
    
    ok($homology->dbID && ($homology->adaptor == $ha));
    debug("homology->dbID = " . $homology->dbID);
    
    my ($id) = $sth->fetchrow_array;
    $sth->finish;
    
    ok($id && $id == $homology->dbID);
    debug("[$id] == [" . $homology->dbID . "]?");
    
    $multi->restore('compara', 'homology');
    $multi->restore('compara', 'homology_member');
    $multi->restore('compara', 'method_link_species_set');
    
    $homologies = $ha->fetch_all_by_method_link_type("$method_link_type");

    ok($homologies);


    done_testing();
};

=cut

done_testing();
