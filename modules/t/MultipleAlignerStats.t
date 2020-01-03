#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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


# load test db
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $compara_db_adaptor = $multi->get_DBAdaptor('compara');

# 1 region of genome_db_id 66 vs 1 region of genome_db_id 90
# 66: 31M2D66M
# 90: 99M
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::CalculateBlockStats',
    {
        'genomic_align_block_ids'   => [4090007433238],
        'compara_db'                => $compara_db_adaptor->url,
    },
    [
        # genome_db_id 66: overall depth and breakdown
        [
            'DATAFLOW',
            {
                'genome_db_id' => '66',
                'num_of_aligned_positions' => 97,
                'num_of_other_seq_positions' => 97,
                'num_of_positions' => 97
            },
            2
        ],
        [
            'DATAFLOW',
            {
                'depth' => '1',
                'genome_db_id' => '66',
                'num_of_positions' => 97
            },
            3
        ],
        # genome_db_id 90: overall depth and breakdown
        [
            'DATAFLOW',
            {
                'genome_db_id' => '90',
                'num_of_aligned_positions' => 97,
                'num_of_other_seq_positions' => 97,
                'num_of_positions' => 99
            },
            2
        ],
        [
            'DATAFLOW',
            {
                'depth' => '0',
                'genome_db_id' => '90',
                'num_of_positions' => 2
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'depth' => '1',
                'genome_db_id' => '90',
                'num_of_positions' => 97
            },
            3
        ],
        # pairwise coverage
        [
            'DATAFLOW',
            {
                'from_genome_db_id' => '66',
                'num_of_aligned_positions' => 97,
                'to_genome_db_id' => '90'
            },
            4
        ],
        [
            'DATAFLOW',
            {
                'from_genome_db_id' => '90',
                'num_of_aligned_positions' => 97,
                'to_genome_db_id' => '66'
            },
            4
        ],
    ]
);


# 3 regions of genome_db_id 90 vs 2 regions of genome_db_id 125
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::CalculateBlockStats',
    {
        'genomic_align_block_ids'   => [5950000028478],
        'compara_db'                => $compara_db_adaptor->url,
    },
    [
        [
            'DATAFLOW',
            {
                'genome_db_id' => '90',
                'num_of_aligned_positions' => 49045,
                'num_of_other_seq_positions' => 49045,
                'num_of_positions' => 49229
            },
            2
        ],
        [
            'DATAFLOW',
            {
                'depth' => '0',
                'genome_db_id' => '90',
                'num_of_positions' => 184
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'depth' => '1',
                'genome_db_id' => '90',
                'num_of_positions' => 49045
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'genome_db_id' => '125',
                'num_of_aligned_positions' => 31597,
                'num_of_other_seq_positions' => 31597,
                'num_of_positions' => 31669
            },
            2
        ],
        [
            'DATAFLOW',
            {
                'depth' => '0',
                'genome_db_id' => '125',
                'num_of_positions' => 72
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'depth' => '1',
                'genome_db_id' => '125',
                'num_of_positions' => 31597
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'from_genome_db_id' => '90',
                'num_of_aligned_positions' => 49045,
                'to_genome_db_id' => '125'
            },
            4
        ],
        [
            'DATAFLOW',
            {
                'from_genome_db_id' => '125',
                'num_of_aligned_positions' => 31597,
                'to_genome_db_id' => '90'
            },
            4
        ],
    ]
);

# 1 region per genome_db_id (61,90,122)
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::CalculateBlockStats',
    {
        'genomic_align_block_ids'   => [5950000145152],
        'compara_db'                => $compara_db_adaptor->url,
    },
    [
        [
            'DATAFLOW',
            {
                'genome_db_id' => '61',
                'num_of_aligned_positions' => 91806,
                'num_of_other_seq_positions' => 144707,
                'num_of_positions' => 110142
            },
            2
        ],
        [
            'DATAFLOW',
            {
                'depth' => '0',
                'genome_db_id' => '61',
                'num_of_positions' => 18336
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'depth' => '1',
                'genome_db_id' => '61',
                'num_of_positions' => 38905
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'depth' => '2',
                'genome_db_id' => '61',
                'num_of_positions' => 52901
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'genome_db_id' => '90',
                'num_of_aligned_positions' => 84480,
                'num_of_other_seq_positions' => 137381,
                'num_of_positions' => 142308
            },
            2
        ],
        [
            'DATAFLOW',
            {
                'depth' => '0',
                'genome_db_id' => '90',
                'num_of_positions' => 57828
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'depth' => '1',
                'genome_db_id' => '90',
                'num_of_positions' => 31579
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'depth' => '2',
                'genome_db_id' => '90',
                'num_of_positions' => 52901
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'genome_db_id' => '122',
                'num_of_aligned_positions' => 64673,
                'num_of_other_seq_positions' => 117574,
                'num_of_positions' => 105736
            },
            2
        ],
        [
            'DATAFLOW',
            {
                'depth' => '0',
                'genome_db_id' => '122',
                'num_of_positions' => 41063
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'depth' => '1',
                'genome_db_id' => '122',
                'num_of_positions' => 11772
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'depth' => '2',
                'genome_db_id' => '122',
                'num_of_positions' => 52901
            },
            3
        ],
        [
            'DATAFLOW',
            {
                'from_genome_db_id' => '61',
                'num_of_aligned_positions' => 82257,
                'to_genome_db_id' => '90'
            },
            4
        ],
        [
            'DATAFLOW',
            {
                'from_genome_db_id' => '61',
                'num_of_aligned_positions' => 62450,
                'to_genome_db_id' => '122'
            },
            4
        ],
        [
            'DATAFLOW',
            {
                'from_genome_db_id' => '90',
                'num_of_aligned_positions' => 82257,
                'to_genome_db_id' => '61'
            },
            4
        ],
        [
            'DATAFLOW',
            {
                'from_genome_db_id' => '90',
                'num_of_aligned_positions' => 55124,
                'to_genome_db_id' => '122'
            },
            4
        ],
        [
            'DATAFLOW',
            {
                'from_genome_db_id' => '122',
                'num_of_aligned_positions' => 62450,
                'to_genome_db_id' => '61'
            },
            4
        ],
        [
            'DATAFLOW',
            {
                'from_genome_db_id' => '122',
                'num_of_aligned_positions' => 55124,
                'to_genome_db_id' => '90'
            },
            4
        ],
    ]
);


# load another test db because the first one doesn't have a species-tree
my $homology = Bio::EnsEMBL::Test::MultiTestDB->new('homology');
my $h_compara_db_adaptor = $homology->get_DBAdaptor('compara');
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::BlockStatsAggregator',
    {
        'mlss_id'                   => 40101,
        'compara_db'                => $h_compara_db_adaptor->url,
        'pairwise_coverage'         => {
            150 => {
                151 => [3, 4],
            },
            151 => {
                150 => [5, 6],
            },
        },
        'genome_length'             => {
            150 => 10,  # 2 more than seen in the blocks. Expect the Runnable to increase some stats by 2
            151 => 13,  # Same as in the blocks
        },
        'num_of_positions'          => {
            150 => [2, 6],
            151 => [9, 4],
        },
        'num_of_aligned_positions'  => {
            150 => [2, 5],
            151 => [8, 4],
        },
        'num_of_other_seq_positions'=> {
            150 => [4, 5],
            151 => [5, 3],
        },
        'depth_by_genome'           => {
            150 => {
                0 => [1, 0],
                1 => [2, 2],
                2 => [1, 3],
            },
            151 => {
                0 => [0, 1],
                2 => [4, 2],
            },
        }
    },
    [
    ]
);

my $stn_150 = $h_compara_db_adaptor->get_SpeciesTreeNodeAdaptor->fetch_by_dbID(40101096);
my $stn_151 = $h_compara_db_adaptor->get_SpeciesTreeNodeAdaptor->fetch_by_dbID(40101086);

is($stn_150->get_value_for_tag('genome_coverage_151'),         7, 'Pairwise coverage 150 -> 151');
is($stn_151->get_value_for_tag('genome_coverage_150'),        11, 'Pairwise coverage 151 -> 150');
is($stn_150->get_value_for_tag('genome_length'),              10, 'num_of_positions 150');
is($stn_150->get_value_for_tag('num_of_positions_in_blocks'),  8, 'num_of_positions 150');
is($stn_150->get_value_for_tag('num_of_aligned_positions'),    7, 'num_of_aligned_positions 150');
is($stn_150->get_value_for_tag('num_of_other_seq_positions'),  9, 'num_of_other_seq_positions 150');
is($stn_151->get_value_for_tag('genome_length'),              13, 'num_of_positions 151');
is($stn_151->get_value_for_tag('num_of_positions_in_blocks'), 13, 'num_of_positions 151');
is($stn_151->get_value_for_tag('num_of_aligned_positions'),   12, 'num_of_aligned_positions 151');
is($stn_151->get_value_for_tag('num_of_other_seq_positions'),  8, 'num_of_other_seq_positions 151');
is($stn_150->get_value_for_tag('num_positions_depth_0'),       3, 'num_positions_depth_0 150');
is($stn_150->get_value_for_tag('num_positions_depth_1'),       4, 'num_positions_depth_1 150');
is($stn_150->get_value_for_tag('num_positions_depth_2'),       4, 'num_positions_depth_2 150');
is($stn_151->get_value_for_tag('num_positions_depth_0'),       1, 'num_positions_depth_0 151');
is($stn_151->get_value_for_tag('num_positions_depth_2'),       6, 'num_positions_depth_2 151');

done_testing();
