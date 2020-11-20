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

use Test::More;
use File::Path qw/remove_tree/;

use Bio::EnsEMBL::Utils::IO qw(slurp);
use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);

SKIP: {
    skip "python3 not installed", 2 unless(`python3 --version 2>/dev/null`);

    # find absolute path to the test input
    # important for travis-ci
    use Cwd 'abs_path';
    my $test_path = abs_path($0);
    my $test_file_dir = $test_path;
    $test_file_dir =~ s!SplitFasta\.t!test_fastas!;

    # set up output directories
    my $test_outdir1 = "$test_file_dir/test1.split";
    mkdir $test_outdir1;
    my $test_outdir2 = "$test_file_dir/test2.split";
    mkdir $test_outdir2;

    # save expected output in array to 'mix-and-match'
    # combinations of the seqs in the test output
    my @possible_output = (
        ">A\nAAAAAAAA\n",
        ">B\nBBBBBBBB\n",
        ">C\nCCCCCCCC\n",
        ">D\nDDDDDDDD\n",
        ">E\nEEEEEEEE\n",
        ">F\nFFFFFFFF\n",
    );

    # test run with num_parts defined
    standaloneJob(
        'ensembl.compara.runnable.SplitFasta',
        {
            'fasta_name' => "$test_file_dir/test.fa",
            'num_parts'  => '2',
            'out_dir'    => "$test_outdir1"
        },
        [], # don't expect any events here
        {
            'language'  => 'python3',
        },
    );
    my @test1_files = glob("$test_outdir1/*");
    is(scalar @test1_files, 2, 'correct number of files generated');
    ok($test1_files[0] =~ /test1\.split\/test\.1\.fasta$/, 'first file named correctly');
    ok($test1_files[1] =~ /test1\.split\/test\.2\.fasta$/, 'second file named correctly');
    is(slurp($test1_files[0]), join('', @possible_output[0,1,2]), 'first file contents correct');
    is(slurp($test1_files[1]), join('', @possible_output[3,4,5]), 'second file contents correct');

    # test run with num_seqs defined
    standaloneJob(
        'ensembl.compara.runnable.SplitFasta',
        {
            'fasta_name' => "$test_file_dir/test.fa",
            'num_seqs'   => '2',
            'out_dir'    => "$test_outdir2"
        },
        [], # don't expect any events here
        {
            'language'  => 'python3',
        },
    );
    my @test2_files = glob("$test_outdir2/*");
    is(scalar @test2_files, 3, 'correct number of files generated');
    ok($test2_files[0] =~ /test2\.split\/test\.1\.fasta$/, 'first file named correctly');
    ok($test2_files[1] =~ /test2\.split\/test\.2\.fasta$/, 'second file named correctly');
    ok($test2_files[2] =~ /test2\.split\/test\.3\.fasta$/, 'third file named correctly');
    is(slurp($test2_files[0]), join('', @possible_output[0,1]), 'first file contents correct');
    is(slurp($test2_files[1]), join('', @possible_output[2,3]), 'second file contents correct');
    is(slurp($test2_files[2]), join('', @possible_output[4,5]), 'third file contents correct');

    # clean up test output
    remove_tree($test_outdir1);
    remove_tree($test_outdir2);

} # /SKIP

done_testing();
