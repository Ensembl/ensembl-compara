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

use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Test::MultiTestDB;

use Test::Most;

BEGIN {
    # Check module can be seen and compiled
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory');
}

# Load test DB #
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('homology_annotation');
my $dba = $multi_db->get_DBAdaptor('compara');
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
my $compara_db = $dbc->url;

# Expected dataflow output
my $exp_dataflow_1 = {
    'member_id_list' => [ 1, 2, 3, 4, 5 ],
    'mlss_id' => 20001,
    'ref_taxa' => 'vertebrates',
};
my $exp_dataflow_2 = {
    'member_id_list' => [ 6, 7, 8, 9 ],
    'mlss_id' => 20001,
    'ref_taxa' => 'vertebrates',
};
my $exp_dataflow_3 = {
    'genome_db_id' => 135,
    'ref_taxa' => 'vertebrates',
};
# Run standalone
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory',
    # Input parameters
    {
        'compara_db'      => $compara_db,
        'step'            => 5,
        'taxon_list'      => ['vertebrates'];
    },
    # Output
    [
        [
            'DATAFLOW',
            $exp_dataflow_1,
            2
        ],
        [
            'DATAFLOW',
            $exp_dataflow_2,
            2
        ],
        [
            'DATAFLOW',
            $exp_dataflow_3,
            1
        ],
    ]
);

done_testing();
