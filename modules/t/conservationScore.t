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
use Test::Exception;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

use Bio::EnsEMBL::Compara::ConservationScore;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $conservation_score_adaptor = $compara_db_adaptor->get_ConservationScoreAdaptor();

my $conservation_score = new Bio::EnsEMBL::Compara::ConservationScore();

isa_ok($conservation_score, "Bio::EnsEMBL::Compara::ConservationScore", "create empty object");

my $exp_score = ("0.123 0.456 0.789");
my $obs_score = ("0.1 0.4 0.7");
my $diff_score = ("0.023 0.056 0.089");
my $rev_exp_score = ("0.789 0.456 0.123");
my $rev_diff_score = ("0.089 0.056 0.023");

my $y_min = 0.123;
my $y_max = 0.789;
my $position = 1;
my $seq_region_pos = 2;
my $packed = 0;
$conservation_score = new Bio::EnsEMBL::Compara::ConservationScore(
                    -adaptor                => $conservation_score_adaptor,
                    -genomic_align_block_id => 1,
                    -window_size            => 1,
                    -position               => $position,
                    -seq_region_pos         => $seq_region_pos,
                    -expected_score         => $exp_score,
                    -diff_score             => $diff_score,
                    -packed                 => $packed,
                    -y_axis_min             => $y_min,
                    -y_axis_max             => $y_max);

isa_ok($conservation_score, "Bio::EnsEMBL::Compara::ConservationScore", "create non-empty object");

is_deeply($conservation_score->adaptor, $conservation_score_adaptor, "adaptor");

is($conservation_score->genomic_align_block_id, 1, "genomic_align_block_id");

is($conservation_score->window_size, 1, "window_size");
is($conservation_score->position, $position, "position");
is($conservation_score->start, $position, "start");
is($conservation_score->end, $position, "end");
is($conservation_score->seq_region_pos, $seq_region_pos, "seq_region_pos");

is($conservation_score->expected_score, $exp_score, "expected score");
is($conservation_score->diff_score, $diff_score, "diff score");
is($conservation_score->score, $diff_score, "score");

#my $obs = $conservation_score->observed_score;
#is($conservation_score->observed_score, $obs_score, "obs_score");

is($conservation_score->y_axis_min, $y_min, "y axis min");
is($conservation_score->y_axis_max, $y_max, "y axis max");

is($conservation_score->packed, $packed, "packed");

#Need to add a dummy gab too 
#$conservation_score->reverse(3);

#is($conservation_score->expected_score, $rev_exp_score, "rev expected score");
#is($conservation_score->diff_score, $rev_diff_score, "rev diff score");

done_testing();
