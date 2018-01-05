#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

use Data::Dumper;
use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Test::MultiTestDB;

BEGIN {
    use Test::Most;
}

# check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection'); 

# Load test DB #
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('orth_qm_wga');
my $dba = $multi_db->get_DBAdaptor('cc21_pair_species');
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
my $compara_db = $dbc->url;

# Test with species_set_name #
my $exp_dataflow = [
	{
	'species_set_id' => '35399',
	'species1_id' => '87',
	'species2_id' => '111'
	},
	{
	'species_set_id' => '35399',
	'species1_id' => '87',
	'species2_id' => '112'
	},
	{
	'species_set_id' => '35399',
	'species1_id' => '87',
	'species2_id' => '142'
	},
	{
	'species_set_id' => '35399',
	'species1_id' => '111',
	'species2_id' => '112'
	},
	{
	'species_set_id' => '35399',
	'species1_id' => '111',
	'species2_id' => '142'
	},
	{
	'species_set_id' => '35399',
	'species1_id' => '112',
	'species2_id' => '142'
	}
];

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection', # module
	{ # input param hash
		'species_set_name' => 'sauropsids', 
		'compara_db' => $compara_db,
	},
	[ # list of events to test for (just 1 event in this case)
		[
			'DATAFLOW',
			$exp_dataflow,
			2
		],
	]
);

# Test species_set_id #
standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection', # module
	{ # input param hash
		'species_set_id' => '35399', 
		'compara_db'     => $compara_db,
	},
	[ # list of events to test for (just 1 event in this case)
		[
			'DATAFLOW',
			$exp_dataflow,
			2
		],
	]
);

# Test with reference
$exp_dataflow = [
	{
	'species_set_id' => '35399',
	'species1_id' => '87',
	'species2_id' => '111'
	},
	{
	'species_set_id' => '35399',
	'species1_id' => '87',
	'species2_id' => '112'
	},
	{
	'species_set_id' => '35399',
	'species1_id' => '87',
	'species2_id' => '142'
	},
];

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection', # module
	{ # input param hash
		'species_set_id' => '35399',
		'ref_species'    => 'taeniopygia_guttata',
		'compara_db'     => $compara_db,
	},
	[ # list of events to test for (just 1 event in this case)
		[
			'DATAFLOW',
			$exp_dataflow,
			2
		],
	]
);


# Test pair of species #
$exp_dataflow = [ { 'species1_id' => '87', 'species2_id' => '111' } ];

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection', # module
	{ # input param hash
		'species1' => 'taeniopygia_guttata', 
		'species2' => 'anolis_carolinensis',
		'compara_db' => $compara_db,
	},
	[ # list of events to test for (just 1 event in this case)
		[
			'DATAFLOW',
			$exp_dataflow,
			2
		],
	]
);

done_testing();
