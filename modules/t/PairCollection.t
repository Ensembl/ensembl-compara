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
use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection'); 

# Load test DB #
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('orth_qm_wga');
my $dba = $multi_db->get_DBAdaptor('cc21_pair_species');
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
my $compara_db = $dbc->url;

# Test collection #
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

my $exp_dataflow2 = [
          {
            'genome_db_id' => '87'
          },
          {
            'genome_db_id' => '111'
          },
          {
            'genome_db_id' => '112'
          },
          {
            'genome_db_id' => '142'
          }
        ];

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection', # module
	{ # input param hash
		'collection' => 'sauropsids', 
		'compara_db' => $compara_db,
	},
	[ # list of events to test for (just 1 event in this case)
		[
			'DATAFLOW',
			$exp_dataflow2,
			2
		],
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			{ 'genome_db_pairs' => $exp_dataflow}, # expected data flowed out
			1 # dataflow branch
		], # end event
		[
			'DATAFLOW',
			{ 'aln_mlss_ids' => undef },
			3
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
			$exp_dataflow2,
			2
		],
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			{ 'genome_db_pairs' => $exp_dataflow}, # expected data flowed out
			1 # dataflow branch
		], # end event
		[
			'DATAFLOW',
			{ 'aln_mlss_ids' => undef },
			3
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
			$exp_dataflow2,
			2
		],
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			{ 'genome_db_pairs' => $exp_dataflow}, # expected data flowed out
			1 # dataflow branch
		], # end event
		[
			'DATAFLOW',
			{ 'aln_mlss_ids' => undef },
			3
		],
	]
);


# Test pair of species #
$exp_dataflow = [ { 'species1_id' => '87', 'species2_id' => '111' } ];
$exp_dataflow2 = [ { 'genome_db_id' => '87' }, { 'genome_db_id' => '111' } ];

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
			$exp_dataflow2,
			2
		],
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			{ 'genome_db_pairs' => $exp_dataflow}, # expected data flowed out
			1 # dataflow branch
		], # end event
		[
			'DATAFLOW',
			{ 'aln_mlss_ids' => undef },
			3
		],
	]
);

done_testing();
