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
use Bio::EnsEMBL::Test::TestUtils;

my $species = [
        "homo_sapiens",
    ];

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $method_adaptor = $compara_db_adaptor->get_MethodAdaptor();

my $method_id = 16;
my $type = "LASTZ_NET";
my $pattern = "GenomicAlignTree.*";

my ($num_class_patterns) = $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT count(*) FROM method_link WHERE class like 'GenomicAlignTree.%'");

my ($num_methods) = $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT count(*) FROM method_link");

my $species_db;
my $species_db_adaptor;
## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (@$species) {
  $species_db->{$this_species} = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  die if (!$species_db->{$this_species});
  $species_db_adaptor->{$this_species} = $species_db->{$this_species}->get_DBAdaptor('core');
}


##
#####################################################################

subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodAdaptor::fetch_by_type", sub {

    my $method = $method_adaptor->fetch_by_type($type);
    
    isa_ok($method, "Bio::EnsEMBL::Compara::Method", "check object");

    $method = $method_adaptor->fetch_by_type("dummy");
    is($method, undef, "Fetching Bio::EnsEMBL::Compara::Method by unknown type");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodAdaptor::fetch_by_class_pattern", sub {

    #Make sure the cache is empty
    $method_adaptor->{_id_cache}->clear_cache;

    my $all_methods_by_pattern = $method_adaptor->fetch_all_by_class_pattern($pattern);
    is(scalar(@$all_methods_by_pattern), $num_class_patterns, "Checking the number of classes by pattern");

    done_testing();
};

#inherited method
subtest "Test Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor::fetch_all", sub {

    #Make sure the cache is empty
    $method_adaptor->{_id_cache}->clear_cache;

    my $all_methods = $method_adaptor->fetch_all();
    is(scalar(@$all_methods), $num_methods, "Checking the number of methods");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor::fetch_by_dbID", sub {

    #Make sure the cache is empty
    $method_adaptor->{_id_cache}->clear_cache;

    my $method = $method_adaptor->fetch_by_dbID($method_id);
    isa_ok($method, "Bio::EnsEMBL::Compara::Method", "check object");

    done_testing();
};

#test adding 2 methods, where the second one already exists
subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodAdaptor::store", sub {

    #save method_link table
    $multi->save('compara', 'method_link');

    #store new method
    my $new_method_id = 1001;
    my $new_type = "LASTZ_RAW";
    my $class = "GenomicAlignBlock.pairwise_alignment";

    my $new_method = new Bio::EnsEMBL::Compara::Method(
                                                   -dbID => $new_method_id,
                                                   -type => $new_type,
                                                   -class => $class);

    $method_adaptor->store($new_method);
     
    #store existing method
    my $method = new Bio::EnsEMBL::Compara::Method(
                                                   -dbID => $method_id,
                                                   -type => $type,
                                                   -class => $class);

    $method_adaptor->store($method);

    my $fetch_method = $method_adaptor->fetch_by_type($new_type);
    isa_ok($fetch_method, "Bio::EnsEMBL::Compara::Method", "check object");

    $fetch_method = $method_adaptor->fetch_by_type($type);
    isa_ok($fetch_method, "Bio::EnsEMBL::Compara::Method", "check object");

    $multi->restore('compara', 'method_link');
    done_testing();
};

done_testing();
