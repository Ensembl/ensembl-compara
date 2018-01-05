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
my $mlss_adaptor = $compara_db_adaptor->get_MethodLinkSpeciesSetAdaptor();
my $dnafrag_adaptor = $compara_db_adaptor->get_DnaFragAdaptor();
my $dnafrag_region_adaptor = $compara_db_adaptor->get_DnaFragRegionAdaptor();
my $synteny_region_adaptor = $compara_db_adaptor->get_SyntenyRegionAdaptor();

my $sth = $compara_db_adaptor->dbc->prepare("SELECT synteny_region_id, method_link_species_set_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand FROM synteny_region JOIN dnafrag_region USING (synteny_region_id) LIMIT 1");
$sth->execute();
my ($synteny_region_id, $method_link_species_set_id, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = $sth->fetchrow_array();
$sth->finish();

my ($num_synteny_regions) = $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT count(*) FROM synteny_region WHERE method_link_species_set_id=$method_link_species_set_id");

subtest "Test Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor fetch_by_dbID($synteny_region_id) method", sub {

   my $synteny_region = $synteny_region_adaptor->fetch_by_dbID($synteny_region_id);

   is($synteny_region->dbID, $synteny_region_id, "dbID");
   done_testing();

};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor store method", sub {

   my $regions = $dnafrag_region_adaptor->fetch_all_by_synteny_region_id($synteny_region_id);
   my $synteny_region = new Bio::EnsEMBL::Compara::SyntenyRegion(
                                                                 -method_link_species_set_id => $method_link_species_set_id,
                                                                 -regions  => $regions);

   $multi->hide("compara", "synteny_region", "dnafrag_region");
   my $sth = $compara_db_adaptor->dbc->prepare("select * from synteny_region");
   $sth->execute;
   is($sth->rows, 0, "Checking that there is no entries left in the <synteny_region> table after hiding it");

   my $new_synteny_region_id = $synteny_region_adaptor->store($synteny_region);

   $sth->execute;
   is($sth->rows, 1, "Checking that there is 1 entry in the <synteny_region> table after store");

   my $new_synteny_region = $synteny_region_adaptor->fetch_by_dbID($new_synteny_region_id);
   is_deeply($new_synteny_region, $synteny_region);

   $multi->restore();

   done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor fetch_all_by_MethodLinkSpeciesSet_DnaFrag method", sub {
    my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
    my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($method_link_species_set_id);

    my $regions = $dnafrag_region_adaptor->fetch_all_by_synteny_region_id($synteny_region_id);
    my $synteny_region = new Bio::EnsEMBL::Compara::SyntenyRegion(-dbID => $synteny_region_id,
                                                                  -adaptor => $synteny_region_adaptor,
                                                                  -method_link_species_set_id => $method_link_species_set_id,
                                                                  -regions  => $regions);

    my $new_synteny_regions = $synteny_region_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($method_link_species_set, $dnafrag);

   is_deeply($new_synteny_regions->[0], $synteny_region);

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor fetch_all_by_MethodLinkSpeciesSet method", sub {

    my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($method_link_species_set_id);
    my $new_synteny_regions = $synteny_region_adaptor->fetch_all_by_MethodLinkSpeciesSet($method_link_species_set);
    is(@$new_synteny_regions, $num_synteny_regions);
    done_testing();
};

done_testing();
