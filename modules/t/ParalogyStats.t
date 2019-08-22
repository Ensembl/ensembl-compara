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

# use Bio::EnsEMBL::ApiVersion;
# use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);

BEGIN {
    use Test::Most;
}

# check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ParalogyStats'); 

# find absolute path to the test output
# important for travis-ci
use Cwd 'abs_path';
my $test_path = abs_path($0);
my $test_flatfile = $test_path;
$test_flatfile =~ s!ParalogyStats\.t!homology_flatfiles/para.test.tsv!;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "homology" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara_db_adaptor );

my $test_homology_mlss_id = 21188;
my $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($test_homology_mlss_id);
standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ParalogyStats', # module
	{ # input param hash
		'mlss_id' => $test_homology_mlss_id,
        'member_type' => 'test',
        'homology_flatfile' => $test_flatfile,
        'compara_db' => $compara_dba->url,
        'debug' => 1,
	}
);

# check a couple of stats values
is( $mlss->get_tagvalue('n_test_within_species_paralog_pairs'), '10', 'within-species paralog pairs correct' );
is( $mlss->get_tagvalue('n_test_gene_split_genes'), '9', 'gene splits correct' );
is( $mlss->get_tagvalue('n_test_other_paralog_groups'), '6', 'other paralog groups correct' );
is( $mlss->get_tagvalue('n_test_paralogs_40133187_pairs'), '9', 'node-specific pairs correct' );
is( $mlss->get_tagvalue('n_test_paralogs_40133001_genes'), '4', 'node-specific gene count correct' );
is( $mlss->get_tagvalue('n_test_paralogs_40133000_groups'), '4', 'node-specific groups correct' );
is( $mlss->get_tagvalue('avg_test_paralogs_40133188_perc_id'), '56.0504', 'average perc_id correct for node' );

done_testing();
