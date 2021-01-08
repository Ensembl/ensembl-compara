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
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Test::MultiTestDB;

use Cwd 'abs_path';

use Test::Most;

BEGIN {
    # Check module can be seen and compiled
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::AddRapidSpecies');
}

# Load test DB
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('homology_annotation');
my $dba = $multi_db->get_DBAdaptor('compara');
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
my $compara_db = $dbc->url;
$multi_db->save('compara', 'genome_db');
# Load core db
my $pan_troglodytes = Bio::EnsEMBL::Test::MultiTestDB->new("pan_troglodytes");
my $pt_dba = $pan_troglodytes->get_DBAdaptor('core');
Bio::EnsEMBL::Registry->add_DBAdaptor('pan_troglodytes', 'core', $pt_dba);
# Expected dataflow
my $exp_dataflow_1 = {
    'genome_db_id' => '135',
    'species_name' => 'canis_lupus_familiaris'
};
my $exp_dataflow_2 = {
    'genome_db_id' => '137',
    'species_name' => 'pan_troglodytes',
};
# Species list inputfile
my $test_species_input = abs_path($0);
$test_species_input    =~ s!addRapidSpecies\.t!homology_annotation_input/species_list_file.txt!;
# Run standalone
standaloneJob(
    # Input parameters
    'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::AddRapidSpecies',
    {
        'compara_db'        => $compara_db,
        'master_db'         => $compara_db,
        'member_db'         => $compara_db,
        'species_list_file' => $test_species_input,
        'release'           => 1,
        'do_not_add'        => {
            'all'         => ['homo_sapiens'],
        },
    },
    # Output
    [
        [
            'WARNING',
            "homo_sapiens is a reference genome"
        ],
        [
            'DATAFLOW',
            $exp_dataflow_1,
            2
        ],
        # [
        #     'DATAFLOW',
        #     $exp_dataflow_2,
        #     2
        # ],
    ]
);
$multi_db->restore('compara', 'genome_db');

done_testing();
