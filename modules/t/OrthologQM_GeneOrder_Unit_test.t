#!/usr/bin/env perl
# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

=pod

=head1 NAME
  
  t::OrthologQM_GeneOrder_Unit_test

=head1 SYNOPSIS

=head1 DESCRIPTION
  A test script to ensure that the orthologQM_gene_conservasion pipeline is running correctly
    Example run

  perl OrthologQM_GeneOrder_Unit_test.t
=cut


#!/usr/bin/env perl
use strict;
use warnings;

#use Data::Dumper;
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);

BEGIN {
    use Test::Most;
}
#load the pre dumped test database
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $dba = $multi_db->get_DBAdaptor('OrthologQM_GeneOrder');
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);

# check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory');

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory', #module
	{ # input param hash
		'compara_db' => $dbc->url,   # Parameters in the test still have to be stringified to mimic the job.input_id table
		'mlss_id'	=>	'100021'
	},

	[
		[
			'DATAFLOW',
			{
          			'ortholog_info_hashref' => {'1045569' => {
                         '46043' => '83505425',
                         '14469' => '83531457',
                         '14803' => '83531457',
                         '14646' => '83531457',
                         '46120' => '83505425'
                       }
                   },
                   'ref_species_dbid' => 31,
                   'non_ref_species_dbid' => 155,
                   'mlss_ID' => 100021
        	},
        	2
			
		],
		[
			"DATAFLOW",
			{	
				'ortholog_info_hashref' => {
        				  '14026395' => {
                          '46043' => '28081004',
                          '14469' => '28074953',
                          '14803' => '28043758'
                        },
          				'14026797' => {
                          '14646' => '57068',
                          '46120' => '51014'
                        }
        		},
        		'ref_species_dbid' => 155,
            	'non_ref_species_dbid' => 31,
            	'mlss_ID' => 100021
             	},
        	2
        ],

        [
        	'DATAFLOW',
        	{
        		'mlss_ID' => 100021
        		},
        		1
        ],
	],
);

use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs'); 
standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs',
	{ # input param hash
	'mlss_ID'=>'100021',
    'ref_species_dbid' => 31,
    'non_ref_species_dbid' => 155,
    'ortholog_info_hashref'	=>	{ '1045569' => {
        '46043' => '83505425',
        '14469' => '83531457',
        '14803' => '83531457',
        '14646' => '83531457',
        '46120' => '83505425'
        }                     
    }
    },

    [
		[
			'DATAFLOW',
			{
				'chr_job' => {
          			'1045569' => [
                    '46043',
                    '46120',
                    '14469',
                    '14646',
                    '14803'
                    ]
        		},
        		'ref_species_dbid' => 31,
                'non_ref_species_dbid' => 155,
                'mlss_ID' => 100021
        	}, 
        	2
        ],
    ],
);


use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Comparison_job_arrays');
standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Comparison_job_arrays',
	{
		'mlss_ID'=>'100021',
		'ref_species_dbid' =>155,
        'non_ref_species_dbid' => 31,
		'chr_job'	=>	{ '14026395' => [
                          '14803',
                          '14469',
                          '46043'
                        	]
                        }

	},
	[
		[
			'DATAFLOW',
			{
				'query' => 14803,
				'left1' => undef,
				'left2' => undef,
				'right1' => 14469,
				'right2' => 46043,
				'ref_chr_dnafragID' => 14026395,
				'ref_species_dbid' => 155,
				'non_ref_species_dbid' => 31,
				'mlss_ID' => 100021
			},
			2
		],

		[
			'DATAFLOW',
			{
				'query' => 14469,
				'right1' => 46043,
				'right2' => undef,
				'left1' => 14803,
				'left2' => undef,
				'ref_chr_dnafragID' => 14026395,
				'ref_species_dbid' => 155,
				'non_ref_species_dbid' => 31,
				'mlss_ID' => 100021
			},
			2
		],

		[
			'DATAFLOW',
			{
				'query' => 46043,
				'left2' => 14803,
				'left1' => 14469,
				'right1' => undef,
				'right2' => undef,
				'ref_chr_dnafragID' => 14026395,
				'ref_species_dbid' => 155,
				'non_ref_species_dbid' => 31,
				'mlss_ID' => 100021
			},
			2
		],
	],
);


use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs');
standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs',
	{
		'compara_db' => $dbc->url,
		'mlss_ID'=>'100021',
		'ref_species_dbid' =>155,
        'non_ref_species_dbid' => 31,
        'ref_chr_dnafragID' =>14026395,
        'query' =>14469,
        'left1' => 14803,
        'right1' => 46043,
    },

    [
		[
			'DATAFLOW',
			{
          		'right1' => 1,
          		'gene_member_id' => '9122578',
          		'dnafrag_id' => '14026395',
          		'left1' => 0,
          		'left2' => undef,
          		'homology_id' => 14469,
          		'method_link_species_set_id' => '100021',
          		'percent_conserved_score' => 25,
          		'right2' => undef
        	},
        	2
        ],
    ],
);

use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score');
standaloneJob(
  'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Ortholog_max_score',
  {
    "db_conn" => $dbc->url,
    'mlss_ID' => '100021',
  },

  [
    [
      'DATAFLOW',
      {
        'method_link_species_set_id' => 100021,
        'homology_id' => 14469,
        'percent_conserved_score' => 50,
      },
      2
    ],

    [
      'DATAFLOW',
      {
        'method_link_species_set_id' => 100021,
        'homology_id' => 14646,
        'percent_conserved_score' => 25,
      },
      2
    ],

    [
      'DATAFLOW',
      {
        'method_link_species_set_id' => 100021,
        'homology_id' => 14803,
        'percent_conserved_score' => 0,
      },
      2
    ],

    [
      'DATAFLOW',
      {
        'method_link_species_set_id' => 100021,
        'homology_id' => 46043,
        'percent_conserved_score' => 25,
      },
      2
    ],

    [
      'DATAFLOW',
      {
        'method_link_species_set_id' => 100021,
        'homology_id' => 46120,
        'percent_conserved_score' => 25,
      },
      2
    ],
  ],
);

done_testing();

