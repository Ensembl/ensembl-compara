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
use Bio::EnsEMBL::Compara::Member;

subtest "Test getter/setter Bio::EnsEMBL::Compara::Member methods", sub {

    my $member = new Bio::EnsEMBL::Compara::Member(
                                                   -dbID => 12,
                                                   -stable_id => "my_dummay_stable_id",
                                                   -description => "dummy gene",
                                                   #-adaptor => "dummy_adaptor",
                                                   -genome_db_id => 1);
    
    isa_ok( $member, "Bio::EnsEMBL::Compara::Member", "check object");
    ok( test_getter_setter( $member, "dbID", 202501 ));
    ok( test_getter_setter( $member, "stable_id", "ENSP00000343934" ));
    ok( test_getter_setter( $member, "version", 1 ));
    ok( test_getter_setter( $member, "description", "my dummy description" ));
    #ok( test_getter_setter( $member, "source_id", 2 ));
    ok( test_getter_setter( $member, "source_name", "ENSEMBLPEP" ));
    #ok( test_getter_setter( $member, "adaptor", "dummy_adaptor" ));
    #ok( test_getter_setter( $member, "chr_name", "14" ));
#    ok( test_getter_setter( $member, "dnafrag_start", 50146593 ));
#    ok( test_getter_setter( $member, "dnafrag_end", 50184785 ));
#    ok( test_getter_setter( $member, "dnafrag_strand", 1 ));
    ok( test_getter_setter( $member, "taxon_id", 9606 ));
    ok( test_getter_setter( $member, "genome_db_id", 1 ));
#    ok( test_getter_setter( $member, "sequence_id", 116289 ));
    
    done_testing();
};

done_testing();





