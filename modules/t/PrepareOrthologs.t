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

use Data::Dumper;
use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Test::MultiTestDB;

use Test::Most;

BEGIN {
    # check module can be seen and compiled
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs');
}

my $exp_dataflow;

# Load test DB #
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('orth_qm_wga');
my $dba = $multi_db->get_DBAdaptor('cc21_prepare_orth');
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
my $compara_db = $dbc->url;

# find absolute path to the test output
# important for travis-ci
use Cwd 'abs_path';
my $test_flatfile = abs_path($0);
$test_flatfile    =~ s!PrepareOrthologs\.t!homology_flatfiles/wga.test.tsv!;
my $test_prev_flatfile = abs_path($0);
$test_prev_flatfile    =~ s!PrepareOrthologs\.t!homology_flatfiles/wga_prev.test.tsv!;
my $test_map_file = abs_path($0);
$test_map_file    =~ s!PrepareOrthologs\.t!homology_flatfiles/prep_orth.hom_map.tsv!;
print "--- test flatfile: $test_flatfile\n";
print "--- test prev_flatfile: $test_prev_flatfile\n";
print "--- test map_file: $test_map_file\n";

# Test on pair of species without reuse #
$exp_dataflow = { orth_info => [
    { id => 101, gene_members => [ [9263633, 134], [9274269, 150] ]},
    { id => 102, gene_members => [ [9263637, 134], [9274269, 150] ]},
    { id => 103, gene_members => [ [9263633, 134], [9284238, 150] ]},
],
    aln_mlss_ids => 54321,
};

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs', # module
	{ # input param hash
        'orth_mlss_id'      => '12345',
        'aln_mlss_ids'      => '54321',
		'species1_id'       => '150',
		'species2_id'       => '134',
		'compara_db'        => $compara_db,
		'orth_batch_size'   => 1,
        'new_alignment'     => 0,
        'homology_flatfile'         => $test_flatfile,
        'homology_mapping_flatfile' => $test_map_file,
        'previous_wga_file'         => 'Not/a/real/file.txt',
	},
	[ # list of events to test for (just 1 event in this case)
		[ # start event
			'DATAFLOW', # event to test for (could be WARNING)
			$exp_dataflow, # expected data flowed out
			2 # dataflow branch
		], # end event
	]
);

# Test on pair of species with reuse #
my $dba_prev = $multi_db->get_DBAdaptor('cc21_prev_orth_test');
my $dbc_prev = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba_prev->dbc);
my $prev_compara_db = $dbc_prev->url;

my $exp_dataflow_2 = { orth_info => [
    { id => 101, gene_members => [ [9263633, 134], [9274269, 150] ]}
],
    aln_mlss_ids => 54321,
};

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs', # module
	{ # input param hash
        'orth_mlss_id'      => '12345',
        'aln_mlss_ids'      => '54321',
		'species1_id'       => '150',
		'species2_id'       => '134',
		'compara_db'        => $compara_db,
		'previous_rel_db'   => $prev_compara_db,
		'orth_batch_size'   => 1,
        'new_alignment'     => 0,
        'homology_flatfile'         => $test_flatfile,
        'homology_mapping_flatfile' => $test_map_file,
        'previous_wga_file'         => $test_prev_flatfile,
    },
    [ # list of events to test for
        [
            'WARNING',
            '2/3 reusable homologies for mlss_id 12345'
        ],
        [
            'DATAFLOW',
            { orth_mlss_id => '12345' },
            3
        ],
        [
            'DATAFLOW',
            $exp_dataflow_2,
            2
        ],
    ]
);

# test reuse output with different batch size
standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs', # module
	{ # input param hash
        'orth_mlss_id'      => '12345',
        'aln_mlss_ids'      => '54321',
		'species1_id'       => '150',
		'species2_id'       => '134',
		'compara_db'        => $compara_db,
		'previous_rel_db'   => $prev_compara_db,
		'orth_batch_size'   => 2,
        'new_alignment'     => 0,
        'homology_flatfile'         => $test_flatfile,
        'homology_mapping_flatfile' => $test_map_file,
        'previous_wga_file'         => $test_prev_flatfile,
    },
    [ # list of events to test for
        [
            'WARNING',
            '2/3 reusable homologies for mlss_id 12345'
        ],
        [
            'DATAFLOW',
            { orth_mlss_id => '12345' },
            3
        ],
        [
            'DATAFLOW',
            $exp_dataflow_2,
            2
        ],
    ]
);


done_testing();
