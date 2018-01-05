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

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $dnafrag_region_adaptor = $compara_db_adaptor->get_DnaFragRegionAdaptor();

my $sth = $compara_db_adaptor->dbc->prepare("SELECT synteny_region_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand FROM dnafrag_region LIMIT 1");
$sth->execute();
my ($synteny_region_id, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = $sth->fetchrow_array();
$sth->finish();

my ($num_dnafrag_regions) = $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT count(*) FROM dnafrag_region WHERE synteny_region_id=$synteny_region_id");

subtest "Test Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor fetch_all_by_synteny_region_id($synteny_region_id) method", sub {

   my $dnafrag_regions = $dnafrag_region_adaptor->fetch_all_by_synteny_region_id($synteny_region_id);

   is(@$dnafrag_regions, $num_dnafrag_regions, "number of dnafrag_regions");

   foreach my $dnafrag_region (@$dnafrag_regions) {
      isa_ok($dnafrag_region, "Bio::EnsEMBL::Compara::DnaFragRegion", "check object");
   }  

   done_testing();

};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor store method", sub {

   my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion(-adaptor => $dnafrag_region_adaptor,
                                                                -synteny_region_id => $synteny_region_id,
                                                                -dnafrag_id        => $dnafrag_id,
                                                                -dnafrag_start     => $dnafrag_start,
                                                                -dnafrag_end       => $dnafrag_end,
                                                                -dnafrag_strand    => $dnafrag_strand);

   $multi->hide("compara", "dnafrag_region");
   my $sth = $compara_db_adaptor->dbc->prepare("select * from dnafrag_region");
   $sth->execute;
   is($sth->rows, 0, "Checking that there is no entries left in the <dnafrag_region> table after hiding it");

   $dnafrag_region_adaptor->store($dnafrag_region);

   $sth->execute;
   is($sth->rows, 1, "Checking that there is 1 entry in the <dnafrag_region> table after store");

   #This returns an array so maybe it should be called fetch_all_by_synteny_region_id?
   my $new_dnafrag_regions = $dnafrag_region_adaptor->fetch_all_by_synteny_region_id($synteny_region_id);
   is_deeply($dnafrag_region, $new_dnafrag_regions->[0]);

   $multi->restore();

   done_testing();
};

done_testing();
