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

use Test::Exception;
use Test::More tests => 2;

use Bio::EnsEMBL::Utils::Iterator;

use Bio::EnsEMBL::Compara::Utils::Scalar;

sub _test_batch_iterator {
    my ($in, $batch_size, $expected_out, $test_name) = @_;
    my $it = Bio::EnsEMBL::Compara::Utils::Scalar::batch_iterator(Bio::EnsEMBL::Utils::Iterator->new($in), $batch_size);
    return is_deeply($it->to_arrayref, $expected_out, $test_name);
}

subtest 'batch_iterator' => sub {
    throws_ok {_test_batch_iterator([], 0)} qr/batch_size must be 1 or greater/, 'batch_size requirement';
    _test_batch_iterator([], 1, [], 'Empty list');
    _test_batch_iterator([3], 1, [[3]], 'Singleton');
    _test_batch_iterator([3], 10, [[3]], 'Singleton@10');
    _test_batch_iterator([1,2], 1, [[1],[2]], 'Pair@1');
    _test_batch_iterator([1,2], 2, [[1,2]], 'Pair@2');
    _test_batch_iterator([1,2], 3, [[1,2]], 'Pair@3');

};

done_testing();
