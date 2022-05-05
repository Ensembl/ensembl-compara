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
use Bio::EnsEMBL::Test::MultiTestDB;
use File::Spec::Functions qw(catfile);
use Test::Most;


BEGIN {
    # check module can be seen and compiled
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CountGenesInTree');
}

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "homology" );
my $compara_dba = $multi->get_DBAdaptor( "compara" );

my $gene_count_exe = catfile(
    $ENV{ENSEMBL_ROOT_DIR},
    'ensembl-compara',
    'scripts',
    'pipeline',
    'count_genes_in_tree.pl'
);

my $test_genome_db_id = 135;
my $test_nctrees_mlss_id = 40102;
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CountGenesInTree',
    {
        'mlss_id'        => $test_nctrees_mlss_id,
        'genome_db_id'   => $test_genome_db_id,
        'compara_db'     => $compara_dba->url,
        'gene_count_exe' => $gene_count_exe,
    }
);

my $tree_adaptor = $compara_dba->get_SpeciesTreeAdaptor();
my $species_tree = $tree_adaptor->fetch_by_method_link_species_set_id_label($test_nctrees_mlss_id, 'default');
my $species_tree_node = $species_tree->root->find_leaves_by_field('genome_db_id', $test_genome_db_id)->[0];
is( $species_tree_node->get_tagvalue('nb_genes_in_tree'), '6', 'nb_genes_in_tree correct' );
is( $species_tree_node->get_tagvalue('nb_genes_unassigned'), '1', 'nb_genes_unassigned correct' );

done_testing();
