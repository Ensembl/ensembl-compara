#!/usr/bin/env perl
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
my $exp_dataflow = {
	'aln_mlss_ids' => [647, 634],
	'species1_id' => '112',
	'species2_id' => '142'
};

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS', # module
	{ # input param hash
		'species1_id' => '112',
		'species2_id' => '142',
		'compara_db'  => $compara_db,
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
			'DATAFLOW',
			{ mlss => [647, 634] },
			1
		],
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			$exp_dataflow, # expected data flowed out
			2 # dataflow branch
		], # end event
	]
);

# Test pair of species sharing an LASTZ aln #
$exp_dataflow = {
	'aln_mlss_ids' => [719],
	'species1_id' => '150',
	'species2_id' => '142'
};

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS', # module
	{ # input param hash
		'species1_id' => '150',
		'species2_id' => '142',
		'compara_db'  => $compara_db,
	},
	[ # list of events to test for (just 1 event in this case)
		[
			'WARNING',
			"Found LASTZ alignment. mlss_id = 719"
		],
		[
			'DATAFLOW',
			{ mlss => [719] },
			1
		],
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			$exp_dataflow, # expected data flowed out
			2 # dataflow branch
		], # end event
	]
);

# Test species set with EPO aln #
$exp_dataflow = {
	'aln_mlss_ids' => [647, 634],
	'species1_id' => '112',
	'species2_id' => '142'
};

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS', # module
	{ # input param hash
		'species1_id'    => '112',
		'species2_id'    => '142',
		'species_set_id' => '35399',
		'compara_db'     => $compara_db,
	},
	[ # list of events to test for (just 1 event in this case)
		[
			'DATAFLOW',
			{ mlss => [647, 634] },
			1
		],
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			$exp_dataflow, # expected data flowed out
			2 # dataflow branch
		], # end event
	]
);

done_testing();