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
use_ok('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthologyStats'); 

# find absolute path to the test output
# important for travis-ci
use Cwd 'abs_path';
my $test_path = abs_path($0);
my $test_flatfile = $test_path;
$test_flatfile =~ s!OrthologyStats\.t!homology_flatfiles/ortho.test.tsv!;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "homology" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara_db_adaptor );

my $test_homology_mlss_id = 21112;
my $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($test_homology_mlss_id);
standaloneJob(
	'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthologyStats', # module
	{ # input param hash
		'mlss_id' => $test_homology_mlss_id,
        'member_type' => 'test',
        'homology_flatfile' => $test_flatfile,
        'compara_db' => $compara_dba->url,
	}
);

# check a couple of stats values
is( $mlss->get_tagvalue('n_test_one-to-one_pairs'), '13', 'one-to-one pairs correct' );
is( $mlss->get_tagvalue('n_test_one-to-many_groups'), '1', 'one-to-many groups correct' );
is( $mlss->get_tagvalue('n_test_many-to-one_111_genes'), '17', 'many_to_one genes correct for genome_db 111' );
is( $mlss->get_tagvalue('n_test_many-to-many_142_genes'), '9', 'many-to-many genes correct for genome_db 142' );
is( $mlss->get_tagvalue('avg_test_one-to-one_142_perc_id'), '33.5242', 'average perc_id correct for genome_db 142' );
is( $mlss->get_tagvalue('avg_test_one-to-many_111_perc_id'), '14.18805', 'average perc_id correct for genome_db 111' );

done_testing();
