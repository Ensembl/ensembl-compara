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

use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);
use Bio::EnsEMBL::Test::MultiTestDB;


BEGIN {
    # Check that the module can be seen and compiled
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids');
}

# Load test database
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('test_master');
my $dba = $multi_db->get_DBAdaptor('compara');
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
my $compara_db = $dbc->url;

# Test that the MLSS id is returned correctly
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',  # module
    { # input param hash
        'master_db'        => $compara_db,
        'method_type'      => 'PROTEIN_TREES',
        'species_set_name' => 'default',
        'release'          => 80,
        'branch_code'      => 2,
    },
    [ # list of events to test for (just 1 event in this case)
        [
            'DATAFLOW',
            {'mlss_id' => 40083},
            2,
        ],
    ],
);

# Test that the MLSS id and its previous MLSS id are returned correctly
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',  # module
    { # input param hash
        'master_db'        => $compara_db,
        'method_type'      => 'NC_TREES',
        'species_set_name' => 'default',
        'release'          => 80,
        'branch_code'      => 2,
        'add_prev_mlss'    => 1,
    },
    [ # list of events to test for (just 1 event in this case)
        [
            'DATAFLOW',
            {'mlss_id' => 40084, 'prev_mlss_id' => 40082},
            2,
        ],
    ],
);

# Test that the MLSS id and its sister MLSS ids are returned correcty
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',  # module
    { # input param hash
        'master_db'        => $compara_db,
        'method_type'      => 'PECAN',
        'species_set_name' => 'amniotes',
        'release'          => 80,
        'branch_code'      => 3,
        'add_sister_mlsss' => 1,
    },
    [ # list of events to test for (just 1 event in this case)
        [
            'DATAFLOW',
            {'mlss_id' => 597, 'ce_mlss_id' => 598, 'cs_mlss_id' => 50039},
            3,
        ],
    ],
);

standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',  # module
    { # input param hash
        'master_db'        => $compara_db,
        'method_type'      => 'EPO',
        'species_set_name' => 'mammals',
        'release'          => 80,
        'branch_code'      => 1,
        'add_sister_mlsss' => 1,
    },
    [ # list of events to test for (just 1 event in this case)
        [
            'DATAFLOW',
            {'mlss_id' => 595, 'ext_mlss_id' => 599, 'ce_mlss_id' => 600, 'cs_mlss_id' => 50040},
            1,
        ],
    ],
);

done_testing();
