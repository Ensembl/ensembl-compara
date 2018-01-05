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

use Test::More;

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

use Bio::EnsEMBL::Compara::GenomicAlignGroup;


#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );

my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );

my $genomic_align_group;
my $genomic_align_adaptor = $compara_db_adaptor->get_GenomicAlignAdaptor;

my $dnafrag_id = 4671099; #cat GeneScaffold_4790 (probably should do this better)
my $dnafrag_adaptor = $compara_db_adaptor->get_DnaFragAdaptor();
my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);

my $cigar_line1 = "200X70M20D10M";
my $cigar_line2 = "100M";
my $cigar_line3 = "100X100M";
my $cigar_line4 = "350X100M";

my $concat_cigar_line = "270M20D10M50X100M";

my $ga1 = new Bio::EnsEMBL::Compara::GenomicAlign(-dbID => 3,
                                                  -dnafrag => $dnafrag,
                                                  -dnafrag_start => 201,
                                                  -dnafrag_end => 300,
                                                  -dnafrag_strand => 1,
                                                  -cigar_line => $cigar_line1,
                                                 );
$ga1->aligned_sequence("AAAA");
my $ga2 = new Bio::EnsEMBL::Compara::GenomicAlign(-dbID => 1,
                                                  -dnafrag => $dnafrag,
                                                  -dnafrag_start => 1,
                                                  -dnafrag_end => 100,
                                                  -dnafrag_strand => 1,
                                                  -cigar_line => $cigar_line2,
                                                 );
$ga2->aligned_sequence("CCC--C");
my $ga3 = new Bio::EnsEMBL::Compara::GenomicAlign(-dbID => 2,
                                                  -dnafrag => $dnafrag,
                                                  -dnafrag_start => 101,
                                                  -dnafrag_end => 200,
                                                  -dnafrag_strand => 1,
                                                  -cigar_line => $cigar_line3,
                                                 );
$ga3->aligned_sequence("G-GGG");

my $ga4 = new Bio::EnsEMBL::Compara::GenomicAlign(-dbID => 3,
                                                  -dnafrag => $dnafrag,
                                                  -dnafrag_start => 350,
                                                  -dnafrag_end => 450,
                                                  -dnafrag_strand => 1,
                                                  -cigar_line => $cigar_line4,
                                                 );
$ga4->aligned_sequence("TT--TT");

my $genomic_align_array = [$ga1, $ga2, $ga3, $ga4];
my $sorted_genomic_align_array = [$ga2, $ga3, $ga1, $ga4];
my $concat_original_sequence = "CCCCGGGGAAAATTTT";

##
#####################################################################

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignGroup::new(void) method", sub {
    $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup();
    isa_ok($genomic_align_group, "Bio::EnsEMBL::Compara::GenomicAlignGroup");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignGroup::new(ALL) method", sub {
    my $genomic_align_group_id = 123;
    $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
                                                                        -dbID    => $genomic_align_group_id,
                                                                        -genomic_align_array => $genomic_align_array
                                                                       );
    isa_ok($genomic_align_group, "Bio::EnsEMBL::Compara::GenomicAlignGroup");
    is($genomic_align_group->dbID, $genomic_align_group_id);
    is(scalar(@{$genomic_align_group->genomic_align_array}), scalar(@{$genomic_align_array}));
    is_deeply($genomic_align_group->genomic_align_array, $genomic_align_array);

    done_testing();
};

subtest "Test getter/setter Bio::EnsEMBL::Compara::GenomicAlignGroup methods", sub {
    my $genomic_align_group_id = 123;
    $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
                                                                        -dbID    => $genomic_align_group_id,
                                                                        -genomic_align_array => $genomic_align_array
                                                                       );
    ok(test_getter_setter($genomic_align_group, "dbID", $genomic_align_group_id));

    is_deeply($genomic_align_group->genomic_align_array, $genomic_align_array);
    done_testing();
};

subtest "Test getter/setter Bio::EnsEMBL::Compara::GenomicAlignGroup get_all_sorted_GenomicAligns", sub {
    my $genomic_align_group_id = 123;
    my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
                                                                           -dbID    => $genomic_align_group_id,
                                                                           -genomic_align_array => $genomic_align_array
                                                                       );
    is_deeply($genomic_align_group->get_all_sorted_GenomicAligns, $sorted_genomic_align_array);
    done_testing();
};

subtest "Test getter/setter Bio::EnsEMBL::Compara::GenomicAlignGroup cigar_line", sub {
    my $genomic_align_group_id = 123;
    my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
                                                                           -dbID    => $genomic_align_group_id,
                                                                           -genomic_align_array => $genomic_align_array
                                                                       );
    is($genomic_align_group->cigar_line, $concat_cigar_line, "check cigar line");
    done_testing();
};

subtest "Test getter/setter Bio::EnsEMBL::Compara::GenomicAlignGroup original_sequence", sub {
    my $genomic_align_group_id = 123;
    my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
                                                                           -dbID    => $genomic_align_group_id,
                                                                           -genomic_align_array => $genomic_align_array
                                                                       );
    is($genomic_align_group->original_sequence, $concat_original_sequence, "check original_sequence");
    done_testing();
};

done_testing();

