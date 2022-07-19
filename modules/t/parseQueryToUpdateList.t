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

use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);

use Cwd 'abs_path';
use Test::Most;

BEGIN {
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::ParseQueryToUpdateList');
}

my $test_path = abs_path($0);
my $test_dir = $test_path;
$test_dir =~ s!parseQueryToUpdateList\.t!homology_annotation_dirs/species_set_record/!;

my $exp_dataflow = {
    queries_to_update => [
        "accipiter_gentilis",
        "oncorhynchus_nerka",
    ],
};

standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::ParseQueryToUpdateList',
    {
        'species_name'        => "homo_sapiens",
        'species_set_record'  => $test_dir,
    },
    [
        [
            'DATAFLOW',
            $exp_dataflow,
            1
        ],
    ]
);

ok(-e "queries_to_update.txt", "Record file exists");
ok(-e $test_dir . "test/homo_sapiens.txt.used", "Used file moved");
ok(-e $test_dir . "test2/homo_sapiens.txt.used", "Used file moved");
ok(-e $test_dir . "test2/canis_lupus_familiaris.txt", "Unused file not moved");

done_testing();
