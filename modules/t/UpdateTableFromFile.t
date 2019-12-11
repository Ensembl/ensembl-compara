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

use Test::Most;

BEGIN {
    # check module can be seen and compiled
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::UpdateTableFromFile');
}

##################################################################################
#                              Test homologies                                   #
##################################################################################
subtest "Test Bio::EnsEMBL::Compara::RunnableDB::UpdateTableFromFile - homologies", sub {
    # Load test DB #
    my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('update_homologies_test');
    my $dba = $multi_db->get_DBAdaptor('compara');
    my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
    my $compara_db = $dbc->url;

    # find absolute path to the test input
    # important for travis-ci
    use Cwd 'abs_path';
    my $test_flatfile_dir = abs_path($0);
    $test_flatfile_dir =~ s!UpdateTableFromFile\.t!homology_flatfiles/update_homologies_test!;

    # run in standalone
    standaloneJob(
        'Bio::EnsEMBL::Compara::RunnableDB::UpdateTableFromFile',
        {
            'compara_db'   => $compara_db,
            'table'        => 'homology',
            'primary_key'  => 'homology_id',
            'attrib_files' => [
                "$test_flatfile_dir/wga.tsv",
                "$test_flatfile_dir/goc.tsv",
                "$test_flatfile_dir/high_conf.tsv",
            ],
        },
    );

    # ensure attributes have been written correctly
    my $homology_adaptor = $dba->get_HomologyAdaptor;
    my $hom_1 = $homology_adaptor->fetch_by_dbID(1);
    is( $hom_1->wga_coverage,  '80.00', 'homology_id 1 wga_coverage correct'       );
    is( $hom_1->goc_score,          25, 'homology_id 1 goc_score correct'          );
    is( $hom_1->is_high_confidence,  1, 'homology_id 1 is_high_confidence correct' );

    my $hom_2 = $homology_adaptor->fetch_by_dbID(2);
    is( $hom_2->wga_coverage,  '90.00', 'homology_id 2 wga_coverage correct'       );
    is( $hom_2->goc_score,          50, 'homology_id 2 goc_score correct'          );
    is( $hom_2->is_high_confidence,  0, 'homology_id 2 is_high_confidence correct' );

    my $hom_3 = $homology_adaptor->fetch_by_dbID(3);
    is( $hom_3->wga_coverage,  '100.00', 'homology_id 3 wga_coverage correct'       );
    is( $hom_3->goc_score,           75, 'homology_id 3 goc_score correct'          );
    is( $hom_3->is_high_confidence,   1, 'homology_id 3 is_high_confidence correct' );

    done_testing();
};

done_testing();
