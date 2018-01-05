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

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_dba = $multi->get_DBAdaptor( "compara" );
my $conservation_score_adaptor = $compara_dba->get_ConservationScoreAdaptor();
my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
my $genomic_align_block_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor;
my $genomic_align_adaptor = $compara_dba->get_GenomicAlignAdaptor;
my $genomic_align_tree_adaptor = $compara_dba->get_GenomicAlignTreeAdaptor;

my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");

my $epo_method_type = "EPO_LOW_COVERAGE";
my $pecan_method_type = "PECAN";
my $cs_method_type = "GERP_CONSERVATION_SCORE";
my $epo_species_set_name = "mammals";
my $pecan_species_set_name = "amniotes";

#Rather complicated way of getting the original 35 and 19 way mlss. Can't use the species_set_name because of the newer addtions for the pipeline tests.
my @mlss_epos = sort {$a->species_set->dbID <=> $b->species_set->dbID} @{$method_link_species_set_adaptor->fetch_all_by_method_link_type($epo_method_type)};
my @mlss_pecans = sort {$a->species_set->dbID <=> $b->species_set->dbID} @{$method_link_species_set_adaptor->fetch_all_by_method_link_type($pecan_method_type)};

my $cs_mlss_epo = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs($cs_method_type,$mlss_epos[0]->species_set->genome_dbs);

my $cs_mlss_pecan = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs($cs_method_type,$mlss_pecans[0]->species_set->genome_dbs);

#my $cs_mlss_epo = $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name($cs_method_type, $epo_species_set_name);
#my $cs_mlss_pecan = $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name($cs_method_type, $pecan_species_set_name);

my $genome_db_id = 90; #human
my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);
my $hs_core_dba = $homo_sapiens->get_DBAdaptor('core');

my $mm_genome_db_id = 134; #mouse
my $mm_genome_db = $genome_db_adaptor->fetch_by_dbID($mm_genome_db_id);
my $mm_core_dba = $mus_musculus->get_DBAdaptor('core');


my $hs_seq_region = "6";
my $hs_slice_start = 31500000;
my $hs_slice_end = 32000000;

my $gab_forward_id = 5990000047741;
my $gab_forward = $genomic_align_block_adaptor->fetch_by_dbID($gab_forward_id);

my $gab_reverse_id = 5990000037295;
my $gab_reverse = $genomic_align_block_adaptor->fetch_by_dbID($gab_reverse_id);
my $gat_reverse_id = 5990001811872;
my $gat_reverse_by_gab = $genomic_align_tree_adaptor->fetch_by_GenomicAlignBlock($gab_reverse);
my $gat_reverse_by_node = $genomic_align_tree_adaptor->fetch_node_by_node_id($gat_reverse_id);

#PECAN
my $gab1_id = 5970000004713;
my $gab1 = $genomic_align_block_adaptor->fetch_by_dbID($gab1_id);

my $gab2_id = 5970000013926;
my $gab2 = $genomic_align_block_adaptor->fetch_by_dbID($gab2_id);

my $gab_small_pecan_id = 5970000013714;
my $gab_small_pecan = $genomic_align_block_adaptor->fetch_by_dbID($gab_small_pecan_id);

my $gab_small_epo_id = 5990000047741;
my $gab_small_epo = $genomic_align_block_adaptor->fetch_by_dbID($gab_small_epo_id);
my $gat_small_id = 5990002291157;

my $gat_small_by_gab = $genomic_align_tree_adaptor->fetch_by_GenomicAlignBlock($gab_small_epo);
my $gat_small_by_node = $genomic_align_tree_adaptor->fetch_node_by_node_id($gat_small_id);

#Need to set a valid leaf in the first position

my $gab3_id = 5970000002090; #No gaps in human till position 197
my $gab3 = $genomic_align_block_adaptor->fetch_by_dbID($gab3_id);

#
#
#
subtest 'forward gab, first 10 scores, no gaps, win_size=1', sub {
    my $window_size= 1;
    my $slice_length = 10;
    my $display_size = $slice_length;
    my $display_type = "AVERAGE";
    my $seq_region = "6";
    my $slice_start = 31683048;
    my $slice_end = $slice_start + $slice_length - 1;
    my $slice = $hs_core_dba->get_adaptor("Slice")->fetch_by_region('toplevel', $seq_region, $slice_start, $slice_end);

    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab_forward_id, $window_size);

    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cs_mlss_epo, $slice, $display_size, $display_type, $window_size);
    
    #Check the first score
    my $conservation_score = $all_conservation_scores->[0];
    isa_ok($conservation_score, "Bio::EnsEMBL::Compara::ConservationScore", "check object");
    is($conservation_score->genomic_align_block_id, $gab_forward_id, "genomic_align_block_id");
    is_deeply($conservation_score->genomic_align_block, $gab_forward, "genomic_align_block");
    is($conservation_score->position, $position, "position");
    is($conservation_score->seq_region_pos, $slice_start, "seq_region_pos");

    is(@$all_conservation_scores, $display_size, "num of scores equals display_size");

    my $i = 0;
    
    foreach my $score (@$all_conservation_scores) {
        is($score->expected_score, $exp_scores->[$i], "exp score $i");
        is($score->diff_score, $diff_scores->[$i], "diff score $i");
        is(sprintf("%.4f",$score->observed_score), sprintf("%.4f", ($exp_scores->[$i]-$diff_scores->[$i])), "obs score $i");
        $i++;
    }
    done_testing();
};

subtest 'Test slice with no scores (mouse)', sub {
    my $window_size= 1;
    my $slice_length = 10;
    my $display_size = $slice_length;
    my $display_type = "AVERAGE";
    my $seq_region = "17";
    my $slice_start = 35028808+250;
    my $slice_end = $slice_start + $slice_length - 1;

    my $slice = $mm_core_dba->get_adaptor("Slice")->fetch_by_region('toplevel', $seq_region, $slice_start, $slice_end);

    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cs_mlss_epo, $slice, $display_size, $display_type, $window_size);

    is(@$all_conservation_scores, 0);

    done_testing();
};

subtest 'Test reverse gab (10 scores)', sub {

    my $window_size= 1;
    my $slice_length = 10;
    my $species_name = "homo_sapiens";
    my $display_size = $slice_length;
    my $display_type = "AVERAGE";

    #Get start and end values
    my $ga = _get_genomic_align($gab_reverse, $species_name);
    my $seq_region = $ga->dnafrag->name;
    my $slice_start = $ga->dnafrag_start;

    my $slice = $hs_core_dba->get_adaptor("Slice")->fetch_by_region('toplevel', $seq_region, $slice_start, ($slice_start+$slice_length-1));

    #get scores in reverse order
    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab_reverse_id, $window_size, -1);

    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cs_mlss_epo, $slice, $display_size, $display_type, $window_size);
    
    #read scores in reverse order
    my $i = @$diff_scores - 1;
    
    foreach my $score (@$all_conservation_scores) {
        is($score->expected_score, $exp_scores->[$i], "exp score $i");
        is($score->diff_score, $diff_scores->[$i], "diff score $i");
        is(sprintf("%.4f",$score->observed_score), sprintf("%.4f", ($exp_scores->[$i]-$diff_scores->[$i])), "obs score $i");
        $i--;
    }

    done_testing();
};

subtest 'Test neighbouring gabs (use PECAN)', sub {

    my $species_name = "homo_sapiens";
    my $window_size= 1;
    my $display_type = "AVERAGE";

    #Get start and end values
    my $ga1 = _get_genomic_align($gab1, $species_name);
    my $seq_region = $ga1->dnafrag->name;
    my $slice_start = $ga1->dnafrag_end - 9;

    my $ga2 = _get_genomic_align($gab2, $species_name);
    my $slice_end = $ga2->dnafrag_start + 9;

    my $display_size = $slice_end-$slice_start+1;

    my $slice = $hs_core_dba->get_adaptor("Slice")->fetch_by_region('toplevel', $seq_region, $slice_start, $slice_end);
    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cs_mlss_pecan, $slice, $display_size, $display_type, $window_size);

    my ($position1, $exp_scores1, $diff_scores1) = _get_single_row_of_scores_from_db($gab1_id, $window_size, -1);
    my ($position2, $exp_scores2, $diff_scores2) = _get_single_row_of_scores_from_db($gab2_id, $window_size);

    #pad at first position of gab2 so start at 1 not 0
    my @exp_scores;
    push @exp_scores, (splice @$exp_scores1, -10 ,10);
    push @exp_scores, (splice @$exp_scores2, 1, 10);

    my @diff_scores;
    push @diff_scores, (splice @$diff_scores1, -10 ,10);
    push @diff_scores, (splice @$diff_scores2, 1, 10);

    my $i = 0;
    foreach my $score (@$all_conservation_scores) {
        is($score->expected_score, $exp_scores[$i], "exp score $i");
        is($score->diff_score, $diff_scores[$i], "diff score $i");
        is(sprintf("%.4f",$score->observed_score), sprintf("%.4f", ($exp_scores[$i]-$diff_scores[$i])), "obs score $i");
        $i++;
    }

    done_testing();
};


subtest 'Test slice starting in region with no scores', sub  {
    
    plan skip_all => 'skip for now';

    my $window_size= 1;
    my $species_name = "homo_sapiens";
    my $display_type = "AVERAGE";

    #Get start and end values
    my $ga = _get_genomic_align($gab2, $species_name);
    my $seq_region = $ga->dnafrag->name;
    my $slice_start = $ga->dnafrag_start-10;
    my $slice_end = $ga->dnafrag_start+10;
    my $display_size = ($slice_end-$slice_start+1);

    my $slice = $hs_core_dba->get_adaptor("Slice")->fetch_by_region('toplevel', $seq_region, $slice_start, $slice_end);
    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cs_mlss_pecan, $slice, $display_size, $display_type, $window_size);

    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab2_id, $window_size);

    my $i = 1;
    foreach my $score (@$all_conservation_scores) {
        is($score->expected_score, $exp_scores->[$i], "exp score $i");
        is($score->diff_score, $diff_scores->[$i], "diff score $i");
        is(sprintf("%.4f",$score->observed_score), sprintf("%.4f", ($exp_scores->[$i]-$diff_scores->[$i])), "obs score $i");
        $i++;
    }
    done_testing();
}; 

subtest 'Test getting all positions/scores of human for small gab (pecan)', sub {
    plan skip_all => 'skip for now';

    my $window_size= 1;
    my $species_name = "homo_sapiens";
    my $display_type = "AVERAGE";

    #Get start and end values
    my $ga = _get_genomic_align($gab_small_pecan, $species_name);
    my $seq_region = $ga->dnafrag->name;
    my $slice_start = $ga->dnafrag_start;
    my $slice_end = $ga->dnafrag_end;
    my $cigar_line = $ga->cigar_line;

    my $display_size = $slice_end-$slice_start+1;

    my $slice = $hs_core_dba->get_adaptor("Slice")->fetch_by_region('toplevel', $seq_region, $slice_start, $slice_end);
    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cs_mlss_pecan, $slice, $display_size, $display_type, $window_size);
    
    my ($position, $exp_scores, $diff_scores) = _get_all_scores_from_db($gab_small_pecan_id, $window_size);

    my @cig = ( $cigar_line =~ /(\d*[GMD])/g );
    my ($cigType, $cigLength);
    my $current = 1;
    my $row = 0;
    my $align_end = 0;
    my $align_start = $position->[0];
    my $align_current = 1;
    my $num_rows = @$position;

    for (my $k = 0; $k < @cig; $k++) {
        my $cigElem = $cig[$k];
    
        $cigType = substr( $cigElem, -1, 1 );
        $cigLength = substr( $cigElem, 0 ,-1 );
        $cigLength = 1 unless ($cigLength =~ /^\d+$/);

        if ($cigType eq "M") {
            for (my $l = 0; $l < $cigLength; $l++) {

                #increment row if finished previous one
                while ($row < ($num_rows-1) && $align_current >= ($position->[$row+1])) {
                    $row++;
                }
                #uncalled region within a match
                if ($align_current >= ($position->[$row] + @{$diff_scores->[$row]})) {
                    $align_current++;
                    next;
                }

                #uncalled alignment score
                if ($diff_scores->[$row][$align_current-$position->[$row]] == 0) {
                    $align_current++;
                } else {
                    is($all_conservation_scores->[$current-1]->diff_score, $diff_scores->[$row][$align_current-$position->[$row]], "diff score $row");
                    is($all_conservation_scores->[$current-1]->expected_score, $exp_scores->[$row][$align_current-$position->[$row]], "exp score $row");
                    $align_current++;
                    $current++;
                }
            }
        } else {
            $align_current += $cigLength;
        }
    }

    done_testing();
};

subtest 'Test getting all scores of human for small gab (epo)', sub {

    plan skip_all => 'skip for now';

    my $window_size= 1;
    my $species_name = "homo_sapiens";
    my $display_type = "AVERAGE";

    #Get start and end values
    my $ga = _get_genomic_align($gab_small_epo, $species_name);
    my $seq_region = $ga->dnafrag->name;
    my $slice_start = $ga->dnafrag_start;
    my $slice_end = $ga->dnafrag_end;
    my $cigar_line = $ga->cigar_line;

    my $display_size = $slice_end-$slice_start+1;

    my $slice = $hs_core_dba->get_adaptor("Slice")->fetch_by_region('toplevel', $seq_region, $slice_start, $slice_end);
    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cs_mlss_epo, $slice, $display_size, $display_type, $window_size);
    
    my ($position, $exp_scores, $diff_scores) = _get_all_scores_from_db($gab_small_epo_id, $window_size);

    my @cig = ( $cigar_line =~ /(\d*[GMD])/g );
    my ($cigType, $cigLength);
    my $current = 1;
    my $row = 0;
    my $align_end = 0;
    my $align_start = $position->[0];
    my $align_current = 1;
    my $num_rows = @$position;

    for (my $k = 0; $k < @cig; $k++) {
        my $cigElem = $cig[$k];
    
        $cigType = substr( $cigElem, -1, 1 );
        $cigLength = substr( $cigElem, 0 ,-1 );
        $cigLength = 1 unless ($cigLength =~ /^\d+$/);

        if ($cigType eq "M") {
            for (my $l = 0; $l < $cigLength; $l++) {

                #increment row if finished previous one
                while ($row < ($num_rows-1) && $align_current >= ($position->[$row+1])) {
                    $row++;
                }
                #uncalled region within a match
                if ($align_current >= ($position->[$row] + @{$diff_scores->[$row]})) {
                    $align_current++;
                    next;
                }

                #uncalled alignment score
                if ($diff_scores->[$row][$align_current-$position->[$row]] == 0) {
                    $align_current++;
                } else {
                    is($all_conservation_scores->[$current-1]->diff_score, $diff_scores->[$row][$align_current-$position->[$row]], "diff score $row");
                    is($all_conservation_scores->[$current-1]->expected_score, $exp_scores->[$row][$align_current-$position->[$row]], "exp score $row");
                    $align_current++;
                    $current++;
                }
            }
        } else {
            $align_current += $cigLength;
        }
    }

    done_testing();
};

subtest 'Test different display size (AVERAGE)', sub {

    my $species_name = "homo_sapiens";
    my $window_size= 1;
    my $display_type = "AVERAGE";
    my $slice_length = 100;

    #Get start and end values
    my $ga1 = _get_genomic_align($gab3, $species_name);

    my $seq_region = $ga1->dnafrag->name;
    my $slice_start = $ga1->dnafrag_start;
    my $slice_end = $ga1->dnafrag_start + $slice_length - 1; #no pads
    my $cigar_line = $ga1->cigar_line;
    my $display_size = 10;

    my $slice = $hs_core_dba->get_adaptor("Slice")->fetch_by_region('toplevel', $seq_region, $slice_start, $slice_end);

    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab3_id, $window_size);

    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cs_mlss_pecan, $slice, $display_size, $display_type, $window_size);

    #need to start at the first base of the species but also need to skip any 
    #uncalled bases at the beginning of the block (position)
    my $sum_diff = 0;
    my $sum_exp = 0;
    my $j = 0;
    my $cnt = 0;
    my $bucket_size = $slice_length/$display_size;
    
    my ($length, $type) = ($cigar_line =~ /(\d*)([GMD])/);
    my $i = 0;
    if ($type eq "D") {
        $i = ($length - $position + 1);
    }
    for (; $i < @$diff_scores; $i++) {
        
        $sum_diff += $diff_scores->[$i];
        $sum_exp += $exp_scores->[$i];
        $cnt++;
        if ($cnt == $bucket_size) {
            my $score = shift(@$all_conservation_scores);
            if (!$score) {
                last;
            }
            is(sprintf("%.4f",$score->diff_score), sprintf("%.4f",($sum_diff/$cnt)), 'diff score $i');
            $sum_diff = 0;
            $sum_exp = 0;
            $cnt = 0;
        }
    }
    done_testing();
};

subtest 'Test different display size (MAX)', sub {

    my $species_name = "homo_sapiens";
    my $window_size= 1;
    my $display_type = "MAX";
    my $slice_length = 100;


    #Get start and end values
    my $ga1 = _get_genomic_align($gab3, $species_name);

    my $seq_region = $ga1->dnafrag->name;
    my $slice_start = $ga1->dnafrag_start;
    my $slice_end = $ga1->dnafrag_start + $slice_length - 1; #no pads
    my $cigar_line = $ga1->cigar_line;
    my $display_size = 10;

    my $slice = $hs_core_dba->get_adaptor("Slice")->fetch_by_region('toplevel', $seq_region, $slice_start, $slice_end);

    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab3_id, $window_size);

    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cs_mlss_pecan, $slice, $display_size, $display_type, $window_size);

    #need to start at the first base of the species but also need to skip any 
    #uncalled bases at the beginning of the block (position)
    my $max_diff = $diff_scores->[0];
    my $cnt = 0;
    my $bucket_size = $slice_length/$display_size;

    for (my $i = 1; $i < @$diff_scores; $i++) {
        #ignore any uncalled scores
        if ($diff_scores->[$i-1] == 0) {
            next;
        }
        if ($diff_scores->[$i-1] > $max_diff) {
            $max_diff = $diff_scores->[$i-1];
        }
        $cnt++;
        if ($cnt == $bucket_size) {
            my $score = shift(@$all_conservation_scores);
            if (!$score) {
                last;
            }
            is($score->diff_score, $max_diff, 'diff score $i');
            $max_diff = $diff_scores->[$i];
            $cnt = 0;
        }
    }

    done_testing();
};


subtest 'Test getting all scores from a genomic_align_block', sub {
    plan skip_all => 'skip for now';

    my $window_size= 1;
    my $species_name = "homo_sapiens";
    my $display_type = "AVERAGE";
    my $display_size = $gab_small_pecan->length;
    my $align_start = 1;
    my $align_end = $gab_small_pecan->length;
    my $slice_length = $gab_small_pecan->length;


    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock($gab_small_pecan, $align_start, $align_end, $slice_length, $display_size, $display_type, $window_size);
    
    my ($position, $exp_scores, $diff_scores) = _get_all_scores_from_db($gab_small_pecan_id, $window_size);

    for (my $i = 0; $i < @$position; $i++) {
        for (my $j = 0; $j < @{$diff_scores->[$i]}; $j++) {
            if ($diff_scores->[$i][$j] != 0) {
                my $score = shift @$all_conservation_scores;
                is($score->position, $position->[$i]+$j, "position $i");
                is($score->expected_score, $exp_scores->[$i][$j], "exp score $i $j");
                is($score->diff_score, $diff_scores->[$i][$j], "diff score $i $j");
                is(sprintf("%.4f",$score->observed_score), sprintf("%.4f", ($exp_scores->[$i][$j]-$diff_scores->[$i][$j])), "obs score $i");
            }
        }
    }

    done_testing();

};

subtest 'Test getting scores from a genomic_align_block (reverse)', sub {
    my $window_size= 1;
    my $species_name = "homo_sapiens";
    my $display_type = "AVERAGE";
    my $display_size = $gab_small_pecan->length;
    my $align_start = 1;
    my $align_end = 10;
    my $slice_length = 10;

    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock($gab_reverse, $align_start, $align_end, $slice_length, $display_size, $display_type, $window_size);
    
    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab_reverse_id, $window_size);

    my $i = 1; #first position has no scores
    foreach my $score (@$all_conservation_scores) {
        is($score->expected_score, $exp_scores->[$i], "exp score $i");
        is($score->diff_score, $diff_scores->[$i], "diff score $i");
        is(sprintf("%.4f",$score->observed_score), sprintf("%.4f", ($exp_scores->[$i]-$diff_scores->[$i])), "obs score $i");
        $i++;
    }
    done_testing();

};

subtest 'Test window_size 10', sub {
    my $display_type = "AVERAGE";
    my $align_start = 1;
    my $align_end = 200;
    my $slice_length = 200;
    my $display_size = 20;
    my $window_size = 10;

    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab_forward_id, $window_size);
    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock($gab_forward, $align_start, $align_end, $slice_length, $display_size, $display_type, $window_size);

    for (my $i = 0; $i < @$all_conservation_scores; $i++) {
        if ($diff_scores->[$i] != 0) {
            my $score = shift(@$all_conservation_scores);
            is($score->position, $position+($i*$window_size));
            is($score->diff_score, $diff_scores->[$i]);	
        }
    }


    done_testing();
};

subtest 'Test window_size 100', sub {
    my $display_type = "AVERAGE";
    my $align_start = 1;
    my $align_end = 1000;
    my $slice_length = 1000;
    my $display_size = 1000;
    my $window_size = 100;

    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab_forward_id, $window_size);
    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock($gab_forward, $align_start, $align_end, $slice_length, $display_size, $display_type, $window_size);

    for (my $i = 0; $i < @$all_conservation_scores; $i++) {
        if ($diff_scores->[$i] != 0) {
            my $score = shift(@$all_conservation_scores);
            is($score->position, $position+($i*$window_size));
            is($score->diff_score, $diff_scores->[$i]);	
        }
    }
    done_testing();
};

subtest 'Test different display sizes AVERAGE', sub {
    my $display_type = "AVERAGE";
    my $align_start = 1;
    my $align_end = 100;
    my $slice_length = 100;
    my $display_size = 10;
    my $window_size = 1;

    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab_forward_id, $window_size);
    
    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock($gab_forward, $align_start, $align_end, $slice_length, $display_size, $display_type, $window_size);

    my $bucket_size = $slice_length/$display_size;
    my $sum_diff = 0;
    my $sum_exp = 0;
    my $cnt = 0;
    for (my $i = 1; $i <= @$diff_scores; $i++) {

        #miss the first score out (minor bug in ConservationScoreAdaptor.pm)
        #if ($i == 1 && $position > 10) {
        #    shift(@$all_conservation_scores);
        #    next;
        #}

        $sum_diff += $diff_scores->[$i-1];
        $sum_exp += $exp_scores->[$i-1];
        $cnt++;
        
        if (($i+$position-1) % $bucket_size == 0) {
            my $score = shift(@$all_conservation_scores);
            if (!$score) {
                last;
            }
            is(sprintf("%.4f",$score->diff_score), sprintf("%.4f",($sum_diff/$cnt)), 'diff_score $i');
            is(sprintf("%.4f",$score->expected_score), sprintf("%.4f",($sum_exp/$cnt)), 'exp_score $i');
            is(sprintf("%.4f",$score->observed_score), sprintf("%.4f",(($sum_exp-$sum_diff)/$cnt)), 'obs_score $i');
            $sum_diff = 0;
            $sum_exp = 0;
            $cnt = 0;
        }
    }
    done_testing();
};

subtest 'Test getting all scores from a genomic_align_block using fetch_by_GenomicAlignBlock using root_id', sub {
    my $window_size= 1;
    my $species_name = "homo_sapiens";
    my $display_type = "AVERAGE";
    my $display_size = $gab_small_epo->length;
    my $align_start = 1;
    my $align_end = 100;
    my $slice_length = 100;

    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock($gat_small_by_gab, $align_start, $align_end, $slice_length, $display_size, $display_type, $window_size);
    
    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab_small_epo_id, $window_size);

    for (my $i = 0; $i < @$all_conservation_scores; $i++) {
        #ignore any uncalled scores
        if ($diff_scores->[$i] == 0) {
            next;
        }
        my $score = shift(@$all_conservation_scores);
        is($score->diff_score, $diff_scores->[$i], 'diff score $i');
    }
};

subtest 'Test getting all scores from a genomic_align_block using fetch_node_by_node_id using root_id', sub {
    my $window_size= 1;
    my $species_name = "homo_sapiens";
    my $display_type = "AVERAGE";
    my $display_size = $gab_small_epo->length;
    my $align_start = 1;
    my $align_end = 100;
    my $slice_length = 100;

    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock($gat_small_by_node, $align_start, $align_end, $slice_length, $display_size, $display_type, $window_size);
    
    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab_small_epo_id, $window_size);

    for (my $i = 0; $i < @$all_conservation_scores; $i++) {
        #ignore any uncalled scores
        if ($diff_scores->[$i] == 0) {
            next;
        }
        my $score = shift(@$all_conservation_scores);
        is($score->diff_score, $diff_scores->[$i], 'diff score $i');
    }
};

subtest 'Test getting all scores from a genomic_align_block by fetch_by_GenomicAlignBlock using root_id (reverse)', sub {
    my $window_size= 1;
    my $species_name = "homo_sapiens";
    my $display_type = "AVERAGE";
    my $display_size = $gab_reverse->length;
    my $align_start = 1;
    my $align_end = 100;
    my $slice_length = 100;

    #change original_strand
    $gat_reverse_by_gab->reverse_complement;
    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock($gat_reverse_by_gab, $align_start, $align_end, $slice_length, $display_size, $display_type, $window_size);
    
    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab_reverse_id, $window_size, -1);
    #read scores in reverse order
    my $i = @$diff_scores - 1;

    foreach my $score (@$all_conservation_scores) {
        #ignore any uncalled scores
        if ($diff_scores->[$i] == 0) {
            next;
        }
        is($score->diff_score, $diff_scores->[$i], "diff score $i");
        $i--;
    }

};

subtest 'Test getting all scores from a genomic_align_block by fetch_node_by_node_id using root_id (reverse)', sub {
    my $window_size= 1;
    my $species_name = "homo_sapiens";
    my $display_type = "AVERAGE";
    my $display_size = $gab_reverse->length;
    my $align_start = 1;
    my $align_end = 100;
    my $slice_length = 100;

    #change original_strand
    $gat_reverse_by_node->reverse_complement;
    my $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock($gat_reverse_by_node, $align_start, $align_end, $slice_length, $display_size, $display_type, $window_size);
    
    my ($position, $exp_scores, $diff_scores) = _get_single_row_of_scores_from_db($gab_reverse_id, $window_size, -1);
    #read scores in reverse order
    my $i = @$diff_scores - 1;

    foreach my $score (@$all_conservation_scores) {
        #ignore any uncalled scores
        if ($diff_scores->[$i] == 0) {
            next;
        }
        is($score->diff_score, $diff_scores->[$i], "diff score $i");
        $i--;
    }

};


done_testing();


########################################################################################
#get scores from database
sub _get_single_row_of_scores_from_db {
    my ($gab_id, $window_size, $orient) = @_;

    my $order = "asc";
    if (!defined $orient) {
        $orient = 1;
    }
    if ($orient == -1) {
        $order = "desc";
    }
    my $sth = $compara_dba->dbc->prepare("SELECT
      position, expected_score, diff_score
    FROM conservation_score WHERE genomic_align_block_id=$gab_id AND window_size = $window_size ORDER BY position $order LIMIT 1");
    $sth->execute();
    my ($position, $expected_score, $diff_score) = $sth->fetchrow_array();
    $sth->finish();
    my @exp_scores = split / /, _unpack_scores($expected_score);
    my @diff_scores = split / /, _unpack_scores($diff_score);

    return ($position, \@exp_scores, \@diff_scores);

} 

sub _get_all_scores_from_db {
    my ($gab_id, $window_size) = @_;
    my $sth = $compara_dba->dbc->prepare("SELECT
      position, expected_score, diff_score
    FROM conservation_score WHERE genomic_align_block_id=$gab_id AND window_size = $window_size ORDER BY position");
    $sth->execute();
    my $i = 0;
    my $exp_scores;
    my $diff_scores;
    my $position;
    while (my @values = $sth->fetchrow_array()) {
        push @$position, $values[0];
        push @$exp_scores, [split / /,_unpack_scores($values[1])];
        push @$diff_scores, [split / /, _unpack_scores($values[2])];
        $i++;
    }
    $sth->finish();
    return ($position, $exp_scores,$diff_scores);

}

#unpack scores.
sub _unpack_scores {
    my ($scores) = @_;

    my $_pack_size = 4;
    my $_pack_type = "f";

    if (!defined $scores) {
	return "";
    }
    my $num_scores = length($scores)/$_pack_size;

    my $score = "";
    for (my $i = 0; $i < $num_scores * $_pack_size; $i+=$_pack_size) {
	my $value = substr $scores, $i, $_pack_size;
	$score .= unpack($_pack_type, $value) . " ";
    }
    return $score;
}

sub _get_genomic_align {
    my ($gab, $species) = @_;

    my $gas = $genomic_align_adaptor->fetch_all_by_GenomicAlignBlock($gab);
    foreach my $ga (@$gas) {
        if ($ga->genome_db->name eq $species) {
            return $ga;
        }
    }
    return undef;
}
