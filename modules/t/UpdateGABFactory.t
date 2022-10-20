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

use Test::Most;

use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


BEGIN {
    # Check module can be seen and compiled
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::UpdateGABFactory');
}

# Load test DB
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('update_msa_test');
my $dba = $multi_db->get_DBAdaptor('compara');
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $dba );

# Test that the module is flowing the right GAB and GAs
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::UpdateGABFactory',  # Module
    {  # Input param hash
        'compara_db'    => $compara_dba->url,
        'mlss_id'       => 2,
        'prev_mlss_id'  => 1,
    },
    [  # List of events to test for
        [
            'DATAFLOW',
            {
                'gab_id'     => 20000000002,
                'ga_id_list' => [ 20000000004 ],
            },
            2
        ],
        [
            'DATAFLOW',
            {
                'gab_id'     => 20000000004,
                'ga_id_list' => [ 20000000008 ],
            },
            2
        ]
    ]
);

done_testing();
