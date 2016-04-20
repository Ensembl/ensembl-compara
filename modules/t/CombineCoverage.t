#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);

BEGIN {
    use Test::Most;
}

# {
#	"orth_id" => 105209540,
# 	"aln_ranges" => {
# 		"7190000155983" => { #gblock_id
# 			142 => [9175789,9175935],
# 			150 => [8685438,8685582]
# 		}
# 	},
# 	"orth_ranges" => {
# 		142 => [9175790,9175921],
# 		150 => [8685439,8685569]
# 	}
# 	"orth_exons" => {
# 		142 => [[9175790,9175921]],
# 		150 => [[8685439,8685569]]
# 	},
# }

# check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CombineCoverage'); 

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CombineCoverage', # module
	{ # input param hash
		'orth_id'           => 'h_id_test',
		'aln_ranges'        => { gblock1 => { 123 => [1,100], 150 => [401,450] }, gblock2 => { 123 => [801,900], 150 => [451,500] } },
		'orth_ranges'       => { 123 => [1,1000], 150 => [1,1000] },
		'orth_exons'        => { 123 => [[1,1000]], 150 => [[1,500 ]] },
	},
	[ # list of events to test for (just 1 event in this case)
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			[ # expected data flowed out
				{ homology_id              => 'h_id_test', 
				  genome_db_id             => 123, 
				  combined_exon_coverage   => 20,
				  combined_intron_coverage => 0,
				  quality_score            => 20,
				  exon_length              => 1000,
				  intron_length            => 0,
				} ,
				{ homology_id              => 'h_id_test', 
				  genome_db_id             => 150, 
				  combined_exon_coverage   => 20,
				  combined_intron_coverage => 0,
				  quality_score            => 20,
				  exon_length              => 500,
				  intron_length            => 500,
				} ,
			],
			1 # dataflow branch
		], # end event
		[
          'DATAFLOW',
          {
            wga_coverage => 20,
            homology_id  => 'h_id_test'
          },
          2
        ]
	]
);

done_testing();

#{'orth_id' => 'h_id_test', 'aln_ranges' => { gblock => { 123 => [[1,100], [801,900]], 150 => [[401,500]] } }, 'orth_ranges' => { 123 => [1,1000], 150 => [1,1000] }, 'orth_exons' => { 123 => [[1,1000]], 150 => [[1,500 ]] } }