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
 
use Test::More tests => 5;
use Test::Exception;

use Bio::EnsEMBL::Compara::Utils::FlatFile;

subtest 'map_row_to_header' => sub {
    my $line_1 = "a\tb\tc\td";
    my $line_2 = "a;b;c;d";
    my @header1 = (1, 2, 3, 4);
    my @header2 = (1, 2);

    is_deeply( 
        Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_1, \@header1), 
        { 1 => 'a', 2 => 'b', 3 => 'c', 4 => 'd' }
    );

    is_deeply( 
        Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_1, "1\t2\t3\t4"), 
        { 1 => 'a', 2 => 'b', 3 => 'c', 4 => 'd' }
    );
    
    is_deeply( 
        Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_1, \@header1, "\t"), 
        { 1 => 'a', 2 => 'b', 3 => 'c', 4 => 'd' }
    );

    is_deeply( 
        Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_1, "1\t2\t3\t4", "\t"), 
        { 1 => 'a', 2 => 'b', 3 => 'c', 4 => 'd' }
    );

    throws_ok { Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_1, \@header2) } qr/Number of columns in header \(2\) do not match row \(4\)/, "Header doesn't match";
    throws_ok { Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_1, "1\t2\t")  } qr/Number of columns in header \(2\) do not match row \(4\)/, "Header doesn't match";
    throws_ok { Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_1, \@header2, "\t") } qr/Number of columns in header \(2\) do not match row \(4\)/, "Header doesn't match";
    throws_ok { Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_1, "1\t2\t", "\t") } qr/Number of columns in header \(2\) do not match row \(4\)/, "Header doesn't match";


    
    is_deeply( 
        Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_2, \@header1, ";"), 
        { 1 => 'a', 2 => 'b', 3 => 'c', 4 => 'd' }
    );

    is_deeply( 
        Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_2, "1;2;3;4", ";"), 
        { 1 => 'a', 2 => 'b', 3 => 'c', 4 => 'd' }
    );

    throws_ok { Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_2, \@header1) } qr/Number of columns in header \(4\) do not match row \(1\)/, "Header doesn't match";
    throws_ok { Bio::EnsEMBL::Compara::Utils::FlatFile::map_row_to_header($line_2, \@header2) } qr/Number of columns in header \(2\) do not match row \(1\)/, "Header doesn't match";



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
        { key1 => 2, key2 => 'd', key3 => 'v', key4 => 10  }, # this line comes from a *.tsv file - will be excluded later
        { key1 => 1, key2 => 'b', key3 => 'y', key4 => 80  },
        { key1 => 1, key2 => 'c', key3 => 'w', key4 => 60  },
        { key1 => 0, key2 => 'a', key3 => 'x', key4 => 90  },
        { key1 => 1, key2 => 'c', key3 => 'w', key4 => 90  },
    ];
    is_deeply( Bio::EnsEMBL::Compara::Utils::FlatFile::query_file_tree( $test_path ), $full_data, 'data read into correct structure' );

    my $selected_data = [
        { key1 => 0, key3 => 'z' },
        { key1 => 1, key3 => 'y' },
        { key1 => 1, key3 => 'y' },
        { key1 => 1, key3 => 'w' },
        { key1 => 0, key3 => 'x' },
        { key1 => 1, key3 => 'w' },
    ];
    is_deeply( Bio::EnsEMBL::Compara::Utils::FlatFile::query_file_tree( $test_path, 'test', ['key1', 'key3'] ), $selected_data, 'correct data selected' );

    my $grouped_data = {
        '0' => {
            'a' => { 'z' => [{key4 => 100}], 'x' => [{key4 => 90}] },
        },
        '1' => {
            'b' => { 'y' => [{key4 => 100}, {key4 => 80}] },
            'c' => { 'w' => [{key4 => 60},  {key4 => 90}] }
        }
    };
    is_deeply( Bio::EnsEMBL::Compara::Utils::FlatFile::query_file_tree( $test_path, 'test', 'key4', ['key1', 'key2', 'key3'] ), $grouped_data, 'correct data selected and grouped' );
};

subtest 'check_line_counts' => sub {
    # find absolute path to the test input
    # important for travis-ci
    use Cwd 'abs_path';
    my $test_path = abs_path($0);
    $test_path =~ s!FlatFile\.t!integrity_checks/!;

    ok( Bio::EnsEMBL::Compara::Utils::FlatFile::check_line_counts("$test_path/file1.txt", 3), 'Line count check passes ok' );
    throws_ok {Bio::EnsEMBL::Compara::Utils::FlatFile::check_line_counts("$test_path/file1.txt", 5)} qr/Expected 5 lines/, 'Line count check fails ok';
};

subtest 'check_column_integrity' => sub {
    # find absolute path to the test input
    # important for travis-ci
    use Cwd 'abs_path';
    my $test_path = abs_path($0);
    $test_path =~ s!FlatFile\.t!integrity_checks/!;

    ok( Bio::EnsEMBL::Compara::Utils::FlatFile::check_column_integrity("$test_path/file1.txt"), 'Column integrity check passes ok' );
    throws_ok {Bio::EnsEMBL::Compara::Utils::FlatFile::check_column_integrity("$test_path/file2.txt")} qr/Expected equal number of columns/, 'Column integrity check fails ok';
    ok( Bio::EnsEMBL::Compara::Utils::FlatFile::check_column_integrity("$test_path/file3.txt", ','), 'Column integrity check passes ok with custom delimiter' );
};

done_testing();
