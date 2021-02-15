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

use Test::More;

use Bio::EnsEMBL::Compara::Method;

# 
# Test new method and all getters
# 

subtest "Test Bio::EnsEMBL::Compara::Method::new(ALL) method", sub {

    my $method_id = 1;
    my $type = "LASTZ_NET";
    my $class = "GenomicAlignBlock.pairwise_alignment";
    my $display_name = 'LastZ';
    my $string = "Method dbID=$method_id $type ($display_name) ~$class";

    my $method = new Bio::EnsEMBL::Compara::Method(
                                                   -dbID => $method_id,
                                                   -type => $type,
                                                   -display_name => $display_name,
                                                   -class => $class);
    isa_ok($method, "Bio::EnsEMBL::Compara::Method");
    is($method->dbID, $method_id);
    is($method->type, $type);
    is($method->class, $class);
    is($method->display_name, $display_name);
    is ($method->toString, $string);

    done_testing();
};

done_testing();

