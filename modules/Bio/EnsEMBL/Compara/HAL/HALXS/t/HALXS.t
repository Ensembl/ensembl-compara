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

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl HALXS.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Data::Dumper;
use File::Basename qw/dirname/;

use Test::More tests => 6;
BEGIN {
    use_ok('HALXS');
    use_ok('HALAdaptor');   # Imported as HALAdaptor but available as Bio::EnsEMBL::Compara::HAL::HALXS::HALAdaptor
};

#########################

my $file_dir = dirname(__FILE__);
my $hal_file = "$file_dir/test.hal";

my $halAdaptor = Bio::EnsEMBL::Compara::HAL::HALXS::HALAdaptor->new($hal_file);
ok($halAdaptor);

my @genomes = qw(rootSeq mhc1 mhc2);
my @hal_genomes = $halAdaptor->genomes();
is_deeply(\@hal_genomes, \@genomes, 'List of genomes');

my %names = (
    rootSeq => 'Root node',
    mhc1    => 'MHC sample 1',
    mhc2    => 'MHC sample 2',
);

subtest 'Metadata', sub {
    foreach my $genome (@genomes) {
        my $genome_metadata = $halAdaptor->genome_metadata($genome);
        my $name = { 'name' => $names{$genome} };
        is_deeply($genome_metadata, $name, 'Correct name for '.$genome);
    }
};

subtest 'Alignment blocks', sub {
    my $ref_pairwise_block = [
        'mhc1',
        0,
        8,
        19,
        '+',
        'TGGCTGTAGGAAACCAGGT',
        'TGGCTGTAGGAAACCAGGT'
    ];

    my $pairwise_blocks_unfiltered = $halAdaptor->pairwise_blocks('mhc1', 'mhc2', 'mhc2', 15, 19);
    is(scalar(@$pairwise_blocks_unfiltered), 2, 'Got 2 blocks');
    is_deeply($pairwise_blocks_unfiltered->[0], $ref_pairwise_block, 'Block 1 as expected');

    # No effect in practice, but still testing it for the sake of it
    my $pairwise_blocks_filtered = $halAdaptor->pairwise_blocks('mhc1', 'mhc2', 'mhc2', 15, 19, 'mhc1');
    is(scalar(@$pairwise_blocks_filtered), 2, 'Got 2 blocks');
    is_deeply($pairwise_blocks_filtered->[0], $ref_pairwise_block, 'Block 1 as expected');

    my $ref_msa_maf = qq{##maf version=1 scoring=N/A
# hal (mhc1:1,mhc2:1)rootSeq;

a
s\tmhc2.mhc2\t15\t4\t+\t700\tAGGT
s\tmhc1.mhc1\t23\t4\t+\t700\tAGGT

};

    my $msa_maf = $halAdaptor->msa_blocks('mhc1', 'mhc2', 'mhc2', 15, 19);
    is($msa_maf, $ref_msa_maf, 'MSA MAF alignment as expected');
};

