#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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

use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Test::MultiTestDB;

use Test::Most;

BEGIN {
    # check module can be seen and compiled
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::MySQLImportHomologies');
}

##################################################################################
#                              Test homologies                                   #
##################################################################################
subtest "Test Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::MySQLImportHomologies", sub {
    # Load test DB #
    my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('mysqlimport_test');
    my $dba = $multi_db->get_DBAdaptor('compara');
    my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
    my $compara_db = $dbc->url;
    $dbc->do("TRUNCATE TABLE homology");

    # find absolute path to the test input
    # important for travis-ci
    use Cwd 'abs_path';
    my $test_flatfile_dir = abs_path($0);
    $test_flatfile_dir =~ s!MySQLImportHomologies\.t!homology_flatfiles/mysqlimport_test!;

    # run in standalone
    standaloneJob(
        'Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::MySQLImportHomologies',
        {
            'compara_db'   => $compara_db,
            'homology_flatfile' => "$test_flatfile_dir/homologies.tsv",
            'attrib_files' => {
                'wga'       => "$test_flatfile_dir/wga.tsv",
                'goc'       => "$test_flatfile_dir/goc.tsv",
                'high_conf' => "$test_flatfile_dir/high_conf.tsv",
            },
            'homology_id_start'  => 11,
            'mlss_id'            => 1234,
            'high_conf_expected' => 1,
        }
    );

    # check main homology data loading
    my $hom_sth = $dba->dbc->prepare("SELECT 
        homology_id, method_link_species_set_id, description, is_tree_compliant,
        species_tree_node_id, gene_tree_node_id, gene_tree_root_id
        FROM homology
        ORDER BY homology_id"
    );
    $hom_sth->execute();
    my $homology_data = $hom_sth->fetchall_arrayref;

    my $exp_hom_data = [
        ['11', '1234', 'ortholog_one2one',  1, '40133018', '14624903', '1377777'],
        ['12', '1234', 'ortholog_one2many', 0, '40133016', '20937479', '2304777'],
        ['13', '1234', 'ortholog_one2one',  1, '40133018', '15053143', '1631777'],
    ];
    is_deeply($homology_data, $exp_hom_data, 'homology data loaded correctly');

    # check homology attribute data loading
    my $attr_sth = $dba->dbc->prepare("SELECT 
        goc_score, wga_coverage, is_high_confidence
        FROM homology
        ORDER BY homology_id"
    );
    $attr_sth->execute();
    my $attrib_data = $attr_sth->fetchall_arrayref;

    my $exp_attr_data = [
        ['0',   undef,   1],
        ['50',  '95.50', 1],
        [undef, '0.00',  0],
    ];
    is_deeply($attrib_data, $exp_attr_data, 'homology attributes loaded correctly');

    # check homology_member data
    my $hom_mem_sth = $dba->dbc->prepare("SELECT * FROM homology_member ORDER BY homology_id, gene_member_id");
    $hom_mem_sth->execute();
    my $hom_mem_data = $hom_mem_sth->fetchall_arrayref;

    my $exp_hom_mem_data = [
        ['11', '607122', '759483',  '20M',     97, 83, 86],
        ['11', '806596', '1021296', '10M5D5M', 99, 85, 87],
        ['12', '681661', '858054',  '10M5D5M', 99, 84, 89],
        ['12', '694925', '875992',  '20M',     99, 84, 89],
        ['13', '213046', '256120',  '20M',     99, 82, 88],
        ['13', '735836', '929326',  '10M5D5M', 76, 63, 67],
    ];
    is_deeply($hom_mem_data, $exp_hom_mem_data, 'homology members loaded correctly');
};

done_testing();
