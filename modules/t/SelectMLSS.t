
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
use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS'); 

# Load test DB #
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('orth_qm_wga');
my $dba = $multi_db->get_DBAdaptor('cc21_select_mlss');
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
my $compara_db = $dbc->url;

# Test pair of species sharing an EPO aln #
my $exp_br1_dataflow = {
	species => '112 - 142',
	accu_dataflow => {
		'aln_mlss_ids' => [647, 634],
		'species1_id' => '112',
		'species2_id' => '142'
	}
};

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS', # module
	{ # input param hash
		'species1_id' => '112',
		'species2_id' => '142',
		'compara_db'  => $compara_db,
		'master_db'   => $compara_db,
	},
	[ # list of events to test for (just 1 event in this case)
		[
			'WARNING',
			"Found EPO alignment. mlss_id = 647"
		],
		[
			'WARNING',
			"Found LASTZ alignment. mlss_id = 634"
		],
		[
			'WARNING',
			"Found 2 alignments between meleagris_gallopavo and gallus_gallus"
		],
		[
			'DATAFLOW',
			$exp_br1_dataflow,
			1
		],
		[ # start event
			'DATAFLOW',
          { 'mlss_id' => '634', 'mlss_db' => $compara_db },
          2
		], # end event
		[ # start event
		  'DATAFLOW',
          { 'mlss_id' => '647', 'mlss_db' => $compara_db },
          2
		], # end event
	]
);

# Test pair of species sharing an LASTZ aln #
$exp_br1_dataflow = {
	species => '150 - 142',
	accu_dataflow => {
		'aln_mlss_ids' => [719],
		'species1_id' => '150',
		'species2_id' => '142'
	}
};

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS', # module
	{ # input param hash
		'species1_id' => '150',
		'species2_id' => '142',
		'compara_db'  => $compara_db,
		'master_db'   => $compara_db,
	},
	[ # list of events to test for (just 1 event in this case)
		[
			'WARNING',
			"Found LASTZ alignment. mlss_id = 719"
		],
		[
			'WARNING',
			"Found 1 alignments between homo_sapiens and gallus_gallus"
		],
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			$exp_br1_dataflow, # expected data flowed out
			1 # dataflow branch
		], # end event
		[
          'DATAFLOW',
          { 'mlss_id' => '719', 'mlss_db' => $compara_db },
          2
        ]
	]
);

# # Test species set with EPO aln #
$exp_br1_dataflow = {
	species => '112 - 142',
	accu_dataflow => {
		'aln_mlss_ids' => [647],
		'species1_id' => '112',
		'species2_id' => '142'
	}
};

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS', # module
	{ # input param hash
		'species1_id'    => '112',
		'species2_id'    => '142',
        'aln_mlss_ids'   => ['647'],
		'compara_db'     => $compara_db,
		'master_db'      => $compara_db,
	},
	[
		# [
		# 	'WARNING',
		# 	"Found 1 alignments between gallus_gallus and meleagris_gallopavo"
		# ],
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			$exp_br1_dataflow, # expected data flowed out
			1 # dataflow branch
		], # end event
		[ # start event
		  'DATAFLOW',
          { 'mlss_id' => '647', 'mlss_db' => $compara_db },
          2
		], # end event
	]
);

done_testing();

