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

BEGIN {
    use Test::Most;
}


# { 
# 	"aln_ranges" => { 
# 		756 => {
# 			125 => [[63450771,63619557]],
# 			151 => [[51060987,51242290]]
# 		}
# 	},
# 	"orth_exons" => {
# 		125 => [[[63577709,63578987],[63575336,63575505],[63575249,63575332]]],
# 		151 => [[[51200848,51202126],[51198506,51198762]]]
# 	},
# 	"orth_id" => 3792462,
# 	"orth_ranges" => {
# 		125 => [63575249,63580867],
# 		151 => [51198506,51202126]
# 	}
# }

# check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CombineCoverage'); 

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CombineCoverage', # module
	{ # input param hash
		'orth_id'     => 'h_id_test',
		'aln_ranges'  => { 
			mlss1 => { 123 => [[1,100]], 150 => [[401,450]] }, 
			mlss2 => { 123 => [[801,900]], 150 => [[451,500]] }
		},
		'orth_ranges' => { 
			123 => [1,1000], 
			150 => [1,1000] 
		},
		'orth_exons'  => { 
			123 => [[1,1000]], 
			150 => [[1,500 ]] 
		},
	},
	[ # list of events to test for (just 1 event in this case)
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			[ # expected data flowed out
				{ homology_id              => 'h_id_test',
				  genome_db_id             => 123,
				  alignment_mlss           => 'mlss1',
				  combined_exon_coverage   => 10,
				  combined_intron_coverage => 0,
				  quality_score            => 10,
				  exon_length              => 1000,
				  intron_length            => 0,
				} ,
				{ homology_id              => 'h_id_test',
				  genome_db_id             => 150,
				  alignment_mlss           => 'mlss1',
				  combined_exon_coverage   => 10,
				  combined_intron_coverage => 0,
				  quality_score            => 10,
				  exon_length              => 500,
				  intron_length            => 500,
				} ,
				{ homology_id              => 'h_id_test', 
				  genome_db_id             => 123,
				  alignment_mlss           => 'mlss2',
				  combined_exon_coverage   => 10,
				  combined_intron_coverage => 0,
				  quality_score            => 10,
				  exon_length              => 1000,
				  intron_length            => 0,
				} ,
				{ homology_id              => 'h_id_test', 
				  genome_db_id             => 150,
				  alignment_mlss           => 'mlss2',
				  combined_exon_coverage   => 10,
				  combined_intron_coverage => 0,
				  quality_score            => 10,
				  exon_length              => 500,
				  intron_length            => 500,
				} ,
			],
			1 # dataflow branch
		], # end event
		[
          'DATAFLOW',
          {
            orth_id  => 'h_id_test'
          },
          2
        ]
	]
);

done_testing();

#{'orth_id' => 'h_id_test', 'aln_ranges' => { gblock => { 123 => [[1,100], [801,900]], 150 => [[401,500]] } }, 'orth_ranges' => { 123 => [1,1000], 150 => [1,1000] }, 'orth_exons' => { 123 => [[1,1000]], 150 => [[1,500 ]] } }