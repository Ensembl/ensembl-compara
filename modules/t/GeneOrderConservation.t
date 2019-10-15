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

use Data::Dumper;
use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Test::MultiTestDB;

BEGIN {
    use Test::Most;
}

# check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GeneOrderConservation'); 

# find absolute path to the test output
# important for travis-ci
use Cwd 'abs_path';
my $test_path = abs_path($0);
my $test_flatfile_dir = $test_path;
$test_flatfile_dir =~ s!GeneOrderConservation\.t!homology_flatfiles!;

# load test db
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "orth_qm_goc" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara_db_adaptor );

# set up reused variables
my $homology_adaptor = $compara_dba->get_HomologyAdaptor;
my ($mlss, $homologies);

##############################
# Test non-polyploid genomes #
##############################

my $goc_mlss_id = 1001;
standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GeneOrderConservation', # module
	{ # input param hash
	    'goc_mlss_id'       => $goc_mlss_id,
        'homology_flatfile' => "$test_flatfile_dir/goc.test.#goc_mlss_id#.tsv",
        'compara_db'        => $compara_dba->url,
	}
);

$mlss       = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($goc_mlss_id);
$homologies = $homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);

# homology_id 1 : gene with no neighbours
my $hom_1 = $homology_adaptor->fetch_by_dbID(1);
is( $hom_1->goc_score, 0, 'correct score (0) for homology_id 1' );

# homology_id 2 : gene with no neighbours on one side + allowing gap of 1
my $hom_2 = $homology_adaptor->fetch_by_dbID(2);
is( $hom_2->goc_score, 50, 'correct score (50) for homology_id 2' );

# homology_id 7 : gene with paralogous neigbours and a large gap (4)
my $hom_7 = $homology_adaptor->fetch_by_dbID(7);
is( $hom_7->goc_score, 75, 'correct score (75) for homology_id 7' );

# homology_id 12 : gene with orphan neighbour and strand mismatch and gap directly adjacent
my $hom_12 = $homology_adaptor->fetch_by_dbID(12);
is( $hom_12->goc_score, 100, 'correct score (100) for homology_id 12' );


###################
# Test polyploidy #
###################

# HOMOEOLOGUES
$goc_mlss_id = 1002;
standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GeneOrderConservation', # module
	{ # input param hash
	    'goc_mlss_id'       => $goc_mlss_id,
        'homology_flatfile' => "$test_flatfile_dir/goc.test.#goc_mlss_id#.tsv",
        'compara_db'        => $compara_dba->url,
        'split_polyploids'  => 1,
	},
    [ # list of events to test for (just 1 event in this case)
		[
			'DATAFLOW',
			{'genome_db_ids' => [4, 5]},
			3
		],
        [
            'WARNING',
            "Got ENSEMBL_HOMOEOLOGUES, so dataflowed 1 job per pair of component genome_dbs\n",
            'INFO'
        ]
	]
);


# ORTHOLOGUES
$goc_mlss_id = 1003;
standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GeneOrderConservation', # module
	{ # input param hash
	    'goc_mlss_id'       => $goc_mlss_id,
        'homology_flatfile' => "$test_flatfile_dir/goc.test.#goc_mlss_id#.tsv",
        'compara_db'        => $compara_dba->url,
        'split_polyploids'  => 1,
	},
    [ # list of events to test for (just 1 event in this case)
		[
			'DATAFLOW',
			{'genome_db_ids' => [1, 4]},
			3
		],
        [
			'DATAFLOW',
			{'genome_db_ids' => [1, 5]},
			3
		],
        [
            'WARNING',
            "Got ENSEMBL_ORTHOLOGUES on polyploids, so dataflowed 1 job per component genome_db\n",
            'INFO'
        ]
	]
);

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GeneOrderConservation', # module
	{ # input param hash
	    'goc_mlss_id'       => $goc_mlss_id,
        'homology_flatfile' => "$test_flatfile_dir/goc.test.#goc_mlss_id#.tsv",
        'compara_db'        => $compara_dba->url,
        'genome_db_ids'     => [1,4],
	}
);

standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GeneOrderConservation', # module
	{ # input param hash
	    'goc_mlss_id'       => $goc_mlss_id,
        'homology_flatfile' => "$test_flatfile_dir/goc.test.#goc_mlss_id#.tsv",
        'compara_db'        => $compara_dba->url,
        'genome_db_ids'     => [1,5],
	}
);

$mlss       = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($goc_mlss_id);
$homologies = $homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);

# homology_id 20 : polyploid genome with cross-component orthologous neighbour and strand mismatches
my $hom_20 = $homology_adaptor->fetch_by_dbID(20);
is( $hom_20->goc_score, 50, 'correct score (50) for homology_id 20' );

# homology_id 20 : polyploid genome with cross-component orthologous neighbour
my $hom_25 = $homology_adaptor->fetch_by_dbID(25);
is( $hom_25->goc_score, 50, 'correct score (50) for homology_id 25' );

done_testing();
