#!/usr/bin/env perl
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
use Cwd 'abs_path';

BEGIN {
    # Check module can be seen and compiled
    use_ok('Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory');
}

# Load test DBs #
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('homology_annotation');
my $dba = $multi_db->get_DBAdaptor('compara');
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
my $compara_db = $dbc->url;

my $ref_multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('test_ref_compara');

my $ref_dba = $ref_multi_db->get_DBAdaptor('compara');
my $ref_dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $ref_dba->dbc);
my $ref_db = $ref_dbc->url;

# Species fasta inputfile
my $ref_dump_dir = abs_path($0);
$ref_dump_dir    =~ s!blastFactoryHomologyAnnotation\.t!homology_annotation_dirs!;

# Shared parameters
my $ref_taxa   = 'collection-mammalia';
my $blast_db_1 = "$ref_dump_dir/homo_sapiens.GRCh38.2019-06.dmnd";
my $blast_db_2 = "$ref_dump_dir/rattus_norvegicus.RGSC3.4.2009-03-Ensembl.dmnd";

# Expected dataflow output
my $exp_dataflow_0 = {
    'genome_db_id' => 135,
    'refcoll_info' => {
        'query_assembly' => 'CanFam3.1',
        'query_genebuild' => '2011-11-Ensembl',
        'query_prodname' => 'canis_lupus_familiaris',
        'ref_coll' => 'collection-mammalia',
        'refdb_version' => 'refdb-test'
        }
};

my $exp_dataflow_1 = {
    'genome_db_id' => 135,
    'ref_taxa' => 'collection-mammalia'
};

my $exp_dataflow_2 = {
    'member_id_list'      => [ 1, 2, 3, 4, 5 ],
    'genome_db_id'        => 135,
    'target_genome_db_id' => 1,
    'ref_taxa'            => $ref_taxa,
    'blast_db'            => $blast_db_1,
};

my $exp_dataflow_3 = {
    'member_id_list'      => [ 6, 7, 8, 9 ],
    'genome_db_id'        => 135,
    'target_genome_db_id' => 1,
    'ref_taxa'            => $ref_taxa,
    'blast_db'            => $blast_db_1,
};

my $exp_dataflow_4 = {
    'member_id_list'      => [ 1, 2, 3, 4, 5 ],
    'genome_db_id'        => 135,
    'target_genome_db_id' => 3,
    'ref_taxa'            => $ref_taxa,
    'blast_db'            => $blast_db_2,
};

my $exp_dataflow_5 = {
    'member_id_list'      => [ 6, 7, 8, 9 ],
    'genome_db_id'        => 135,
    'target_genome_db_id' => 3,
    'ref_taxa'            => $ref_taxa,
    'blast_db'            => $blast_db_2,
};

my $exp_dataflow_6 = {
    'genome_db_pairs' => [
        { 'genome_db_id' => 135, 'ref_genome_db_id' => 1 },
        { 'genome_db_id' => 135, 'ref_genome_db_id' => 3 },
    ]
};

# Run standalone
standaloneJob(
    'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory',
    # Input parameters
    {
        'compara_db'    => $compara_db,
        'step'          => 4,
        'rr_ref_db'     => $ref_db,
        'species_list'  => [ 'canis_lupus_familiaris' ],
        'ref_dump_dir'  => $ref_dump_dir,
    },
    # Output
    [
        [
            'DATAFLOW',
            $exp_dataflow_0,
            4
        ],
        [
            'DATAFLOW',
            $exp_dataflow_1,
            1
        ],
        [
            'DATAFLOW',
            $exp_dataflow_2,
            2
        ],
        [
            'DATAFLOW',
            $exp_dataflow_3,
            2
        ],
        [
            'DATAFLOW',
            $exp_dataflow_4,
            2
        ],
        [
            'DATAFLOW',
            $exp_dataflow_5,
            2
        ],
        [
            'DATAFLOW',
            $exp_dataflow_6,
            3
        ]
    ]
);

done_testing();
