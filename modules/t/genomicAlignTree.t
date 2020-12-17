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

use Test::More;

use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::GenomicAlignTree;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

my $length_no_gaps = 20;
my $length_with_gaps = 8;
my $full_aln_string = 'T' x $length_no_gaps;
my $gap_aln_string = ('T' x ($length_with_gaps/2)) . ('-' x ($length_no_gaps-$length_with_gaps)) . ('T' x ($length_with_gaps/2));
my @restrict_pos = ($length_with_gaps/2+2, $length_no_gaps-$length_with_gaps/2-1);
my $length_restricted = $restrict_pos[1] - $restrict_pos[0] + 1;

my $tree_string = '(((((A,B)C,D)E,(F,G)H)I,J)K,L)M;';
my %dnafrags;
{
    my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($tree_string);
    foreach my $node (@{$tree->get_all_nodes}) {
        my $name = $node->name;
        my $gdb = new Bio::EnsEMBL::Compara::GenomeDB(
            -NAME => $name,
            # We hijack the assembly field to record whether this is an ancestor or not
            -ASSEMBLY => $node->is_leaf ? 'species' : 'ancestor',
        );
        $dnafrags{$name} = new Bio::EnsEMBL::Compara::DnaFrag(
            -GENOME_DB => $gdb,
            -NAME => 'chr',
        );
    }
}


sub make_tree_with_gaps {
    my $nodes_with_gaps = shift;
    my $gat = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($tree_string, 'Bio::EnsEMBL::Compara::GenomicAlignTree');
    foreach my $node (@{$gat->get_all_nodes}) {
        my $ga = new Bio::EnsEMBL::Compara::GenomicAlign(
            -DNAFRAG => $dnafrags{$node->name},
            -DNAFRAG_START => 1,
            -DNAFRAG_END => $nodes_with_gaps->{$node->name} ? $length_with_gaps : $length_no_gaps,
            -DNAFRAG_STRAND => 1,
            -ALIGNED_SEQUENCE => $nodes_with_gaps->{$node->name} ? $gap_aln_string : $full_aln_string,
        );
        my $gag = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
            -GENOMIC_ALIGN_ARRAY => [$ga],
        );
        $node->genomic_align_group($gag);
    }
    return $gat;
}

sub check_restrict {
    my ($set_gaps, $expect_gaps) = @_;
    my %nodes_with_gaps = map {$_ => 1} @$set_gaps;
    my $tree = make_tree_with_gaps(\%nodes_with_gaps);
    my $rtree = $tree->restrict_between_alignment_positions(@restrict_pos, 'skip_empty_GenomicAligns');
    my %expected_gaps = map {$_ => 1} @$expect_gaps;
    subtest join('', @$set_gaps, (scalar(@$expect_gaps) ? ('/', @$expect_gaps) : ())) => sub {
        $tree->print;
        $rtree->print;
        foreach my $node (@{$rtree->get_all_nodes}) {
            note $node->name;
            note $node->_toString;
            my $gag = $node->genomic_align_group;
            if ($node->is_leaf) {
                is($gag->genome_db->assembly, 'species', 'Leaf is not ancestral_sequences');
            } else {
                is($gag->genome_db->assembly, 'ancestor', 'Internal node is ancestral_sequences');
                is($node->get_child_count, 2, 'Internal node is binary');
            }
            if ($expected_gaps{$gag->genome_db->name}) {
                # restrict_between_alignment_positions has correctly left this node in, but it is only gaps
                is($gag->dnafrag_start, $restrict_pos[0]-1, 'dnafrag_start');
                is($gag->dnafrag_end, $restrict_pos[0]-2, 'dnafrag_end');
                is(length($gag->aligned_sequence), $length_restricted, 'alignment length');
                is(length($gag->original_sequence), 0, 'empty sequence');

            } elsif($nodes_with_gaps{$gag->genome_db->name}) {
                # restrict_between_alignment_positions should have removed this node
                fail($node->name . '(' . $gag->genome_db->name . ') is still present');

            } else {
                is($gag->dnafrag_start, $restrict_pos[0], 'dnafrag_start');
                is($gag->dnafrag_end, $restrict_pos[1], 'dnafrag_end');
                is(length($gag->aligned_sequence), $length_restricted, 'alignment length');
                is(length($gag->original_sequence), $length_restricted, 'sequence length');
            }
        }
    };
}

subtest 'Bio::EnsEMBL::Compara::GenomicAlignTree::restrict_between_alignment_positions' => sub {
    # The gaps should all disappear after restriction / minimisation
    check_restrict(['A'], []);
    check_restrict(['A', 'B'], []);
    check_restrict(['A', 'C'], []);
    check_restrict(['A', 'D'], []);
    check_restrict(['A', 'B', 'C', 'D'], []);
    check_restrict(['J'], []);
    check_restrict(['J', 'K'], []);
    check_restrict(['L'], []);
    # Some gaps should be retained because they hold the tree together
    check_restrict(['C'], ['C']);
    check_restrict(['K'], ['K']);
    check_restrict(['M'], ['M']);
};

done_testing;
