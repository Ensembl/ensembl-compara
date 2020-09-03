#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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

use File::Basename ();

use Test::More;
use Test::Exception;

use Bio::EnsEMBL::Test::MultiTestDB;

use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

my $t_dir = File::Basename::dirname( File::Basename::dirname( Cwd::realpath($0) ) );

# load human test db, which has the non_ref
my $human_testdb = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens', $t_dir);
my $human_dba = $human_testdb->get_DBAdaptor('core');

my $wheat_testdb = Bio::EnsEMBL::Test::MultiTestDB->new('triticum_aestivum', $t_dir);
my $wheat_dba = $wheat_testdb->get_DBAdaptor('core');

subtest 'human', sub {
    my $human_expected_slices = $human_dba->get_SliceAdaptor->fetch_all('toplevel', undef, 1, 1, 1);
    ok(scalar(@$human_expected_slices), 'Found some slices to test');

    my $human_it = Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor::iterate_toplevel_slices($human_dba);
    isa_ok($human_it, 'Bio::EnsEMBL::Utils::Iterator', 'human_it');

    my $human_slices = $human_it->to_arrayref();
    _test_slices($human_slices, $human_expected_slices);
};

subtest 'wheat', sub {
    my $genome_component = 'B';

    my $wheat_expected_slices = $wheat_dba->get_SliceAdaptor->fetch_all_by_genome_component($genome_component);
    ok(scalar(@$wheat_expected_slices), 'Found some slices to test');

    my $wheat_it = Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor::iterate_toplevel_slices($wheat_dba, $genome_component);
    isa_ok($wheat_it, 'Bio::EnsEMBL::Utils::Iterator', 'wheat_it');

    my $wheat_slices = $wheat_it->to_arrayref();
    _test_slices($wheat_slices, $wheat_expected_slices);
};

sub _test_slices {
    my ($got_slices, $expected_slices, $slice_name) = @_;

    is(scalar(@$got_slices), scalar(@$expected_slices), 'Correct number of slices in the iterator');

    my @sorted_got_slices = sort {$a->seq_region_name cmp $b->seq_region_name} @$got_slices;
    my @sorted_expected_slices = sort {$a->seq_region_name cmp $b->seq_region_name} @$expected_slices;

    while (@sorted_got_slices and @sorted_expected_slices) {
        _test_slice((shift @sorted_got_slices), (shift @sorted_expected_slices));
    }
}

sub _test_slice {
    my ($got_slice, $expected_slice) = @_;
    subtest 'seq_region_name '.$expected_slice->seq_region_name, sub {
        isa_ok($got_slice, 'Bio::EnsEMBL::Slice', 'got_slice');
        is($got_slice->{'attributes'}->{'seq_region_id'}, $expected_slice->get_seq_region_id(), 'correct seq_region_id');
        foreach my $attrib (qw(seq_region_name seq_region_length seq_region_start seq_region_end strand)) {
            is($got_slice->$attrib, $expected_slice->$attrib, "correct $attrib");
        }
        is(exists $got_slice->{'attributes'}->{'non_ref'} ? 0 : 1, $expected_slice->is_reference(), 'correct is_reference '.$expected_slice->is_reference());
    };
}

done_testing();

