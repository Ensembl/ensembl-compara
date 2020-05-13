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
 
use Test::More tests => 3;
use Test::Exception;

use Bio::EnsEMBL::Compara::Utils::FlatFile;

subtest 'map_row_to_header' => sub {
    my $line = "a\tb\tc\td";
    my @header1 = (1, 2, 3, 4);
    my @header2 = (1, 2);

    is_deeply( 
        Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line, \@header1), 
        { 1 => 'a', 2 => 'b', 3 => 'c', 4 => 'd' }
    );
    throws_ok { Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line, \@header2) } qr/Number of columns in header do not match row/, "Header doesn't match";
};

subtest 'group_array_of_hashes_by' => sub {
    my $data = [
        { 'key_a' => 'val_a1', 'key_b' => 'val_b1', 'key_c' => 'val_c1' },
        { 'key_a' => 'val_a1', 'key_b' => 'val_b2', 'key_c' => 'val_c2' },
        { 'key_a' => 'val_a2', 'key_b' => 'val_b2', 'key_c' => 'val_c3' },
        { 'key_a' => 'val_a3', 'key_b' => 'val_b3', 'key_c' => 'val_c4' },
    ];
    
    my $exp_group_1 = {
        'val_a1' => [ 
            { 'key_a' => 'val_a1', 'key_b' => 'val_b1', 'key_c' => 'val_c1' },
            { 'key_a' => 'val_a1', 'key_b' => 'val_b2', 'key_c' => 'val_c2' },
        ],
        'val_a2' => [ { 'key_a' => 'val_a2', 'key_b' => 'val_b2', 'key_c' => 'val_c3' } ],
        'val_a3' => [ { 'key_a' => 'val_a3', 'key_b' => 'val_b3', 'key_c' => 'val_c4' } ],
    };
    is_deeply( Bio::EnsEMBL::Compara::Utils::FlatFile::group_hash_by( $data, ['key_a'] ), $exp_group_1, 'grouped on single field');
    
    my $exp_group_2 = {
        'val_a1' => { 
            'val_b1' => [ { 'key_a' => 'val_a1', 'key_b' => 'val_b1', 'key_c' => 'val_c1' } ],
            'val_b2' => [ { 'key_a' => 'val_a1', 'key_b' => 'val_b2', 'key_c' => 'val_c2' } ],
        },
        'val_a2' => {
            'val_b2' => [ { 'key_a' => 'val_a2', 'key_b' => 'val_b2', 'key_c' => 'val_c3' } ],
        },
        'val_a3' => {
            'val_b3' => [ { 'key_a' => 'val_a3', 'key_b' => 'val_b3', 'key_c' => 'val_c4' } ],
        },
    };
    is_deeply( Bio::EnsEMBL::Compara::Utils::FlatFile::group_hash_by( $data, ['key_a', 'key_b'] ), $exp_group_2, 'grouped on multiple fields');

    my $exp_group_3 = {
        'val_a1' => { 
            'val_b1' => [ { 'key_c' => 'val_c1' } ],
            'val_b2' => [ { 'key_c' => 'val_c2' } ],
        },
        'val_a2' => {
            'val_b2' => [ { 'key_c' => 'val_c3' } ],
        },
        'val_a3' => {
            'val_b3' => [ { 'key_c' => 'val_c4' } ],
        },
    };
    is_deeply( Bio::EnsEMBL::Compara::Utils::FlatFile::group_hash_by( $data, ['key_a', 'key_b'], ['key_c'] ), $exp_group_3, 'grouped on multiple fields with select');
};

subtest 'query_file_tree' => sub {
    # find absolute path to the test input
    # important for travis-ci
    use Cwd 'abs_path';
    my $test_path = abs_path($0);
    $test_path =~ s!FlatFile\.t!test_flatfiles/!;

    my $full_data = [
        { key1 => 0, key2 => 'a', key3 => 'z', key4 => 100 },
        { key1 => 1, key2 => 'b', key3 => 'y', key4 => 100 },
        { key1 => 0, key2 => 'a', key3 => 'x', key4 => 90  },
        { key1 => 1, key2 => 'c', key3 => 'w', key4 => 90  },
        { key1 => 1, key2 => 'b', key3 => 'y', key4 => 80  },
        { key1 => 1, key2 => 'c', key3 => 'w', key4 => 60  },
    ];
    is_deeply( Bio::EnsEMBL::Compara::Utils::FlatFile::query_file_tree( $test_path ), $full_data, 'data read into correct structure' );

    my $selected_data = [
        { key1 => 0, key3 => 'z' },
        { key1 => 1, key3 => 'y' },
        { key1 => 0, key3 => 'x' },
        { key1 => 1, key3 => 'w' },
        { key1 => 1, key3 => 'y' },
        { key1 => 1, key3 => 'w' },
    ];
    is_deeply( Bio::EnsEMBL::Compara::Utils::FlatFile::query_file_tree( $test_path, 'test', ['key1', 'key3'] ), $selected_data, 'correct data selected' );

    my $grouped_data = {
        '0' => {
            'a' => { 'z' => [{key4 => 100}], 'x' => [{key4 => 90}] },
        },
        '1' => {
            'b' => { 'y' => [{key4 => 100}, {key4 => 80}] },
            'c' => { 'w' => [{key4 =>  90}, {key4 => 60}] }
        }
    };
    is_deeply( Bio::EnsEMBL::Compara::Utils::FlatFile::query_file_tree( $test_path, 'test', 'key4', ['key1', 'key2', 'key3'] ), $grouped_data, 'correct data selected and grouped' );
};

done_testing();
