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

my $ma = $compara_dba->get_GeneMemberAdaptor;

my ($member_id, $stable_id, $version, $source_name, $taxon_id, $genome_db_id, $sequence_id,
    $gene_member_id, $description, $chr_name, $chr_start, $chr_end, $chr_strand) =
        $compara_dba->dbc->db_handle->selectrow_array("SELECT * FROM member WHERE source_name = 'ENSEMBLGENE' LIMIT 1");

subtest "Test fetch methods", sub {

    ok(1);


    my $member = $ma->fetch_by_stable_id($stable_id);
    
    ok($member);
    ok( $member->dbID,  $member_id);
    ok( $member->stable_id, $stable_id );
    ok( $member->version, $version );
    ok( $member->description, $description );
    ok( $member->source_name, $source_name );
    ok( $member->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor") );
    ok( $member->chr_name, $chr_name );
    ok( $member->dnafrag_start, $chr_start );
    ok( $member->dnafrag_end, $chr_end );
    ok( $member->dnafrag_strand, $chr_strand );
    ok( $member->taxon_id, $taxon_id );
    ok( $member->genome_db_id, $genome_db_id );
    ok( ! $member->sequence_id );

    ($member_id, $stable_id, $version, $source_name, $taxon_id, $genome_db_id, $sequence_id,
     $gene_member_id, $description, $chr_name, $chr_start, $chr_end, $chr_strand) =
       $compara_dba->dbc->db_handle->selectrow_array("SELECT * FROM member WHERE source_name = 'ENSEMBLPEP' LIMIT 1");
    
    # FIXME should be using SeqMemberAdaptor
    $member = $ma->fetch_by_stable_id($stable_id);
    
    ok($member);
    ok( $member->dbID,  $member_id);
    ok( $member->stable_id, $stable_id );
    ok( $member->version, $version );
    ok( $member->description, $description );
    ok( $member->source_name, $source_name );
    ok( $member->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor") );
    ok( $member->chr_name, $chr_name );
    ok( $member->dnafrag_start, $chr_start );
    ok( $member->dnafrag_end, $chr_end );
    ok( $member->dnafrag_strand, $chr_strand );
    ok( $member->taxon_id, $taxon_id );
    ok( $member->genome_db_id, $genome_db_id );
    ok( $member->sequence_id );
    
    
    $multi->hide('compara', 'member');
    $member->{'_dbID'} = undef;
    $member->{'_adaptor'} = undef;
    
    $ma->store($member);
    
    my $sth = $compara_dba->dbc->prepare('SELECT member_id
                                FROM member
                                WHERE member_id = ?');
    
    $sth->execute($member->dbID);
    
    ok($member->dbID && ($member->adaptor == $ma));
    debug("member->dbID = " . $member->dbID);
    
    my ($id) = $sth->fetchrow_array;
    $sth->finish;
    
    ok($id && $id == $member->dbID);
    debug("[$id] == [" . $member->dbID . "]?");
    
    $multi->restore('compara', 'member');


    done_testing();
};

=cut

done_testing();

