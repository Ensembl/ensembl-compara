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
use Bio::EnsEMBL::Compara::Homology;

subtest "Test getter/setter Bio::EnsEMBL::Compara::Homology methods", sub {

    my $homology = new Bio::EnsEMBL::Compara::Homology(
                                                       -dbID => 12,
                                                       -stable_id => "my_dummy_stable_id",
                                                       -description => "dummy gene",
                                                       #-adaptor => "dummy_adaptor",
                                                       -method_link_species_set_id => 6);

    #$homology->method_link_type("ENSEMBL_ORTHOLOGUES");
    #$homology->method_link_id(2);
    
    isa_ok( $homology, "Bio::EnsEMBL::Compara::Homology", "check object" );
    ok( test_getter_setter( $homology, "dbID", 202501 ));
    ok( test_getter_setter( $homology, "stable_id", "dummy stable_id" ));
    ok( test_getter_setter( $homology, "description", "my dummy description" ));
    ok( test_getter_setter( $homology, "method_link_species_set_id", 2 ));
    #ok( test_getter_setter( $homology, "method_link_id", 2 ));
    #ok( test_getter_setter( $homology, "method_link_type", "blablablo" ));
    #ok( test_getter_setter( $homology, "adaptor", "dummy_adaptor" ));

    done_testing();
};

done_testing();




