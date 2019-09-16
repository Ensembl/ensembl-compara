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

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);

BEGIN {
    use Test::Most;
}

# check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping'); 

# find absolute path to the test output
# important for travis-ci
use Cwd 'abs_path';
my $test_path = abs_path($0);
my ($curr_hom_flatfile, $prev_hom_flatfile) = ($test_path, $test_path);
$curr_hom_flatfile =~ s!HomologyIDMapping\.t!homology_flatfiles/hom_map.test.tsv!;
$prev_hom_flatfile =~ s!HomologyIDMapping\.t!homology_flatfiles/hom_map_prev.test.tsv!;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "homology" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara_db_adaptor );

my $test_homology_mlss_id = 21112;
my $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($test_homology_mlss_id);
standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping', # module
	{ # input param hash
		'mlss_id' => $test_homology_mlss_id,
        'previous_mlss_id' => $test_homology_mlss_id,
        'homology_flatfile' => $curr_hom_flatfile,
        'prev_homology_flatfile' => $prev_hom_flatfile,
        'compara_db' => $compara_dba->url,
	}
);

my $exp_output = [
    ['13037',   '13036',   $test_homology_mlss_id],
    ['13045',   '13044',   $test_homology_mlss_id],
    ['974335',  '974334',  $test_homology_mlss_id],
    ['2089891', '2089890', $test_homology_mlss_id],
    ['2094923', '2094922', $test_homology_mlss_id],
];

my $sth = $compara_dba->dbc->prepare('SELECT * FROM homology_id_mapping ORDER BY prev_release_homology_id');
$sth->execute();
my $results = $sth->fetchall_arrayref;

is_deeply( $results, $exp_output, 'ids mapped correctly' );

done_testing();
