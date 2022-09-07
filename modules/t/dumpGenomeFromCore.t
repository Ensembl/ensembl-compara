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

use File::Compare qw(compare);
use File::Spec::Functions qw(catfile rel2abs);
use File::Temp qw(tempdir);
use Test::Most;

use Bio::EnsEMBL::Compara::Utils::Test;
use Bio::EnsEMBL::Test::MultiTestDB;


my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('triticum_aestivum');
my $core_dbc = $multi_db->get_DBAdaptor('core')->dbc;

my $genome_dump_exe = catfile(
    $ENV{ENSEMBL_ROOT_DIR},
    'ensembl-compara',
    'scripts',
    'dumps',
    'dump_genome_from_core.pl'
);

my $dump_file_name = 'triticum_aestivum_B.fa';

# find absolute path to the reference file - important for travis-ci
my $ref_flatfile_dir = rel2abs(__FILE__);
$ref_flatfile_dir =~ s!dumpGenomeFromCore\.t$!dump_flatfiles!;
my $ref_dump_file = catfile($ref_flatfile_dir, $dump_file_name);

my $tmp_dir = tempdir( CLEANUP => 1 );
my $test_dump_file = catfile($tmp_dir, $dump_file_name);

my @comp_dump_command = (
    $genome_dump_exe,
    '--core-db'          => $core_dbc->dbname,
    '--host'             => $core_dbc->host,
    '--port'             => $core_dbc->port,
    '--outfile'          => $test_dump_file,
    '--genome-component' => 'B',
);

Bio::EnsEMBL::Compara::Utils::Test::test_command(\@comp_dump_command, "Can execute $genome_dump_exe");
is(compare($test_dump_file, $ref_dump_file), 0, 'Wheat genome component dump file matches reference file');

done_testing();
