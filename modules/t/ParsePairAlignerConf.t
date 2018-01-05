#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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
use Bio::EnsEMBL::Hive::AnalysisJob;
use Bio::EnsEMBL::Hive::Utils::Test qw(standaloneJob);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Test::MultiTestDB;

BEGIN {
    use Test::More;
}

# check module can be seen and compiled
use_ok('Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf'); 

# # load test db
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('parse_pair_aligner_conf');
my $dba = $multi_db->get_DBAdaptor('compara');
my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $dba->dbc);
my $gdb_adaptor = $dba->get_GenomeDBAdaptor;

# setup
my $default_parameters = {
    default => 'T=1 L=3000 H=2200 O=400 E=30 --ambiguous=iupac', # ensembl genomes settings
    7742    => 'T=1 K=3000 L=3000 H=2200 O=400 E=30 --ambiguous=iupac', # vertebrates - i.e. ensembl-specific
    9443    => 'T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=/test/ensembl-compara/scripts/pipeline/primate.matrix --ambiguous=iupac', # primates
};

my $pair_aligner = {};
$pair_aligner->{'method_link'} = [1001, 'LASTZ_RAW'];

my $dummy_job = Bio::EnsEMBL::Hive::AnalysisJob->new();
$dummy_job->param_init( {
        'default_parameters'    => $default_parameters,
        'master_db'             => $dbc,    # can be a URL too
    } );

my $pair_aligner_conf = Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf->new();
$pair_aligner_conf->input_job($dummy_job);

# test vertebrate setting
# dog v cat
my $dog_gdb = $gdb_adaptor->fetch_by_dbID(135);
my $cat_gdb = $gdb_adaptor->fetch_by_dbID(139);
my $vert_pa = { %$pair_aligner };
my $exp_vert_pa = {
	method_link => [1001, 'LASTZ_RAW'],
	analysis_template => { parameters => { options => $default_parameters->{7742} } },
};

ok($pair_aligner_conf->set_pair_aligner_options(
	$vert_pa,
	$dog_gdb,
	$cat_gdb,
), 'set_pair_aligner_options method runs for dog v cat');

is_deeply( $vert_pa, $exp_vert_pa, 'correct vertebrate settings registered' );

# test primate setting
# human v chimp
my $human_gdb = $gdb_adaptor->fetch_by_dbID(150);
my $chimp_gdb = $gdb_adaptor->fetch_by_dbID(221);
my $prim_pa = { %$pair_aligner };
my $exp_prim_pa = {
	method_link => [1001, 'LASTZ_RAW'],
	analysis_template => { parameters => { options => $default_parameters->{9443} } },
};

ok($pair_aligner_conf->set_pair_aligner_options(
	$prim_pa,
	$human_gdb,
	$chimp_gdb,
), 'set_pair_aligner_options method runs for human v chimp');

is_deeply( $prim_pa, $exp_prim_pa, 'correct primate settings registered' );

# test ensembl genomes setting
# c.int v human (can reuse gdb)
my $c_int_gdb = $gdb_adaptor->fetch_by_dbID(128);
my $ens_pa = { %$pair_aligner };
my $exp_ens_pa = {
	method_link => [1001, 'LASTZ_RAW'],
	analysis_template => { parameters => { options => $default_parameters->{default} } },
};

ok($pair_aligner_conf->set_pair_aligner_options(
	$ens_pa,
	$human_gdb,
	$c_int_gdb,
), 'set_pair_aligner_options method runs for human v ciona');

is_deeply( $ens_pa, $exp_ens_pa, 'correct ensembl-wide settings registered' );

done_testing();