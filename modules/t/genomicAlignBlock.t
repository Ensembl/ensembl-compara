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

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::AlignIO;

my $species = [
        "homo_sapiens",
         "felis_catus",
    ];

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

my $species_db;
my $species_db_adaptor;
## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (@$species) {
  $species_db->{$this_species} = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  die if (!$species_db->{$this_species});
  $species_db_adaptor->{$this_species} = $species_db->{$this_species}->get_DBAdaptor('core');
}

##
#####################################################################

my $genomic_align_adaptor = $compara_db_adaptor->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_db_adaptor->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_db_adaptor->get_MethodLinkSpeciesSetAdaptor();

#Set up gabs and gas
my $sth = $compara_db_adaptor->dbc->prepare("
    SELECT
      ga1.genomic_align_id, ga2.genomic_align_id, gab.genomic_align_block_id,
      gab.method_link_species_set_id, gab.score, gab.perc_id, gab.length, gab.group_id, gab.level_id
    FROM genomic_align ga1, genomic_align ga2, genomic_align_block gab
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      and ga1.genomic_align_id != ga2.genomic_align_id
      and ga1.genomic_align_block_id = gab.genomic_align_block_id
      and ga1.cigar_line LIKE \"\%D\%\" and ga2.cigar_line LIKE \"\%D\%\"
      and ga1.dnafrag_strand = 1 and ga2.dnafrag_strand = 1 LIMIT 1");
$sth->execute();
my ($genomic_align_1_dbID, $genomic_align_2_dbID, $genomic_align_block_id,
    $method_link_species_set_id, $score, $perc_id, $length, $group_id, $level_id) =
    $sth->fetchrow_array();
$sth->finish();

my $genomic_align_blocks;
my $genomic_align_block;
my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
my $genomic_align_1 = $genomic_align_adaptor->fetch_by_dbID($genomic_align_1_dbID);
my $genomic_align_2 = $genomic_align_adaptor->fetch_by_dbID($genomic_align_2_dbID);
my $genomic_align_array = [$genomic_align_1, $genomic_align_2];

my $slice_adaptor = $species_db_adaptor->{$genomic_align_1->dnafrag->genome_db->name}->get_SliceAdaptor();
my $slice_coord_system_name = $genomic_align_1->dnafrag->coord_system_name;
my $slice_seq_region_name = $genomic_align_1->dnafrag->name;
my $slice_start = $genomic_align_1->dnafrag_start;
my $slice_end = $genomic_align_1->dnafrag_end;
my $slice = $slice_adaptor->fetch_by_region($slice_coord_system_name,$slice_seq_region_name,$slice_start,$slice_end);

$genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
isa_ok($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignBlock", "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->new(void) method");

subtest 'Test creation of GenomicAlignBlock object', sub {
    $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                                                                        -adaptor => $genomic_align_block_adaptor,
                                                                        -dbID => $genomic_align_block_id,
                                                                        -method_link_species_set => $method_link_species_set,
                                                                        -score => $score,
                                                                        -length => $length,
                                                                        -genomic_align_array => $genomic_align_array
                                                                       );
    isa_ok($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignBlock", 'check object');
    is($genomic_align_block->adaptor, $genomic_align_block_adaptor, 'adaptor');
    is($genomic_align_block->dbID, $genomic_align_block_id, 'dbID');
    is($genomic_align_block->method_link_species_set, $method_link_species_set, 'method_link_species_set');
    is($genomic_align_block->score, $score, 'score');
    is($genomic_align_block->length, $length, 'length');
    is($genomic_align_block->genomic_align_array, $genomic_align_array,'genomic_align_array');
};

# 
# Getter/Setter tests
# 
subtest "Test getter/setter Bio::EnsEMBL::Compara::GenomicAlignBlock methods", sub {
    my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();

    ok(test_getter_setter($genomic_align_block, "adaptor", $genomic_align_block_adaptor));
    ok(test_getter_setter($genomic_align_block, "dbID", $genomic_align_block_id));
    ok(test_getter_setter($genomic_align_block, "method_link_species_set", $method_link_species_set));
    ok(test_getter_setter($genomic_align_block, "method_link_species_set_id", $method_link_species_set_id));
    ok(test_getter_setter($genomic_align_block, "genomic_align_array", $genomic_align_array));
    ok(test_getter_setter($genomic_align_block, "score", $score));
    ok(test_getter_setter($genomic_align_block, "perc_id", $perc_id));
    ok(test_getter_setter($genomic_align_block, "length", $length));
    ok(test_getter_setter($genomic_align_block, "group_id", $group_id));
    ok(test_getter_setter($genomic_align_block, "level_id", $level_id));
    
    done_testing();
};


# 
# Test Bio::EnsEMBL::Compara::GenomicAlignBlock methods
# 
subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock methods", sub {
    my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                                                                           -adaptor => $genomic_align_block_adaptor,
                                                                           -dbID => $genomic_align_block_id,
                                                                          );
    is($genomic_align_block->score, $score, "Trying to get score from the database");
    is($genomic_align_block->perc_id, $perc_id, "Trying to get perc_id from the database");
    is($genomic_align_block->length, $length,"Trying to get length from the database");
    is($genomic_align_block->group_id, $group_id,"Trying to get group_id from the database");
    is($genomic_align_block->level_id, $level_id,"Trying to get level_id from the database");
    is($genomic_align_block->method_link_species_set_id, $method_link_species_set_id, "Trying to get method_link_species_set_id from the database");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->method_link_species_set method", sub {
    $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                                                                        -adaptor => $genomic_align_block_adaptor,
                                                                        -method_link_species_set_id => $method_link_species_set_id,
                                                                       );
    is($genomic_align_block->method_link_species_set->dbID, $method_link_species_set_id,
       "Trying to get method_link_species_set object from method_link_species_set_id");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->method_link_species_set_id method", sub {
    my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                                                                        -method_link_species_set => $method_link_species_set,
                                                                       );
    is($genomic_align_block->method_link_species_set_id, $method_link_species_set_id,
       "Trying to get method_link_species_set_id from method_link_species_set object");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_genomic_align_id method", sub {
    my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                                                                           -adaptor => $genomic_align_block_adaptor,
                                                                           -dbID => $genomic_align_block_id,
                                                                          );
    $genomic_align_block->reference_genomic_align_id(0);
    is($genomic_align_block->reference_genomic_align, undef);
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_genomic_align method", sub {
    my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
                                                                                                     $method_link_species_set,
                                                                                                     $slice
                                                                                                    );
    
    my $genomic_align_block = $genomic_align_blocks->[0];

    isa_ok($genomic_align_block->reference_genomic_align, "Bio::EnsEMBL::Compara::GenomicAlign", "GenomicAlign object");

    my $first_reference_genomic_align_id = $genomic_align_block->reference_genomic_align->dbID;
    my $second_reference_genomic_align =  $genomic_align_block->get_all_non_reference_genomic_aligns->[0];
    $genomic_align_block->reference_genomic_align_id($second_reference_genomic_align->dbID);
    is($genomic_align_block->reference_genomic_align->dbID, $second_reference_genomic_align->dbID);
    $genomic_align_block->reference_genomic_align->{dbID} = undef;
    $genomic_align_block->{reference_genomic_align_id} = undef;
    is(@{$genomic_align_block->get_all_non_reference_genomic_aligns}, 1,
       "Testing get_all_non_reference_genomic_aligns when reference_genomic_align has no dbID");
    done_testing;
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->genomic_align_array method", sub {
  my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                                                                         -adaptor => $genomic_align_block_adaptor,
                                                                         -dbID => $genomic_align_block_id,
                                                                        );
  is(scalar(@{$genomic_align_block->genomic_align_array}), scalar(@{$genomic_align_array}), "Trying to get genomic_align_array from the database");

  #Can't use is_deeply because not all fields of the genomic_aligns are populated ie dnafrag and genomic_align_block
  done_testing();


};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->add_GenomicAlign method", sub {
    my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
    foreach my $this_genomic_align (@$genomic_align_array) {
        $genomic_align_block->add_GenomicAlign($this_genomic_align);
    }
    is(@{$genomic_align_block->get_all_GenomicAligns}, @$genomic_align_array);
    is_deeply($genomic_align_block->genomic_align_array, $genomic_align_array);
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->genomic_align_array method", sub {
    my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                                                                           -adaptor => $genomic_align_block_adaptor,
                                                                           -dbID => $genomic_align_block_id,
                                                                          );
    is(scalar(@{$genomic_align_block->get_all_GenomicAligns}), scalar(@{$genomic_align_array}),
       "Trying to get method_link_species_set_id from the database");

    do {
        my $all_fails;
        foreach my $this_genomic_align (@{$genomic_align_block->get_all_GenomicAligns}) {
            my $fail = $this_genomic_align->dbID;
            foreach my $that_genomic_align (@$genomic_align_array) {
                if ($that_genomic_align->dbID == $this_genomic_align->dbID) {
                    $fail = undef;
                    last;
                }
            }
            $all_fails .= " <$fail> " if ($fail);
        }
        is($all_fails, undef, "Trying to get method_link_species_set_id from the database (returns the unexpected genomic_align_id)");
    };
    done_testing();
}; 

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice method", sub {
   my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
                                                                                                    $method_link_species_set,
                                                                                                    $slice
                                                                                                   );
   is($genomic_align_blocks->[0]->reference_slice, $slice, "reference_slice");
   done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->alignment_strings method", sub {
    my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                                                                           -dbID => $genomic_align_block_id,
                                                                           -adaptor => $genomic_align_block_adaptor
                                                                          );
    is(scalar(@{$genomic_align_block->alignment_strings}), scalar(@{$genomic_align_array}));
    #Can't easily recreate the alignment string from the genomic_align_array so at least check the gaps are in the right place.
    my @new_cigar_lines;
    foreach my $string (@{$genomic_align_block->alignment_strings}) {
        my $new_cigar_line;
        
        my @pieces = grep {$_} split(/(\-+)|(\.+)/, $string);
        foreach my $piece (@pieces) {
            my $mode;
            if ($piece =~ /\-/) {
                $mode = "D"; # D for gaps (deletions)
            } elsif ($piece =~ /\./) {
                $mode = "X"; # X for pads (in 2X genomes)
            } else {
                $mode = "M"; # M for matches/mismatches
            }
            if (length($piece) == 1) {
                $new_cigar_line .= $mode;
            } elsif (length($piece) > 1) { #length can be 0 if the sequence starts with a gap
                $new_cigar_line .= CORE::length($piece).$mode;
            }
        }
        push @new_cigar_lines, $new_cigar_line;
    }

    my $found = 0;
    foreach my $ga (@$genomic_align_array) {
        my $cigar_line = $ga->cigar_line;
        print "cigar_line $cigar_line\n";
        foreach my $new_cigar_line (@new_cigar_lines) {
            if ($cigar_line eq $new_cigar_line) {
                $found++;
            }
        }
    }
    is($found, 2, "Test alignment_strings");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reverse_complement method", sub {
  my  $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice);

  my $genomic_align_block = $genomic_align_blocks->[0];
  my $genomic_align_array = $genomic_align_block->genomic_align_array;
  $genomic_align_block->reverse_complement;
  
  my $st = $genomic_align_block->reference_genomic_align;
  is( $st->dnafrag_strand, -1, 'ref dnafrag_strand');
  like( $st->cigar_line, qr/M/, 'ref cigar_line');

  my $res = $genomic_align_block->get_all_non_reference_genomic_aligns->[0];
  is( $res->dnafrag_strand, -1, 'non-ref dnafrag_strand' );
  like( $res->cigar_line, qr/M/, 'non-ref cigar_line');
  done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->get_SimpleAlign", sub {
    my  $genomic_align_block = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice)->[0];
    my $alignIO = Bio::AlignIO->newFh(
                                      -interleaved => 0,
                                      -fh => \*STDOUT,
                                      -format => "clustalw",
                                      -idlength => 10,
                                      -linelength => 100);

    #Not sure how to test this...
    my $simple_align = $genomic_align_block->get_SimpleAlign();
    print $alignIO $simple_align;
    pass();
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->get_all_ungapped_GenomicAlignBlocks method", sub {
    my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice
      ($method_link_species_set,
       $slice);

    my $genomic_align_block = $genomic_align_blocks->[0];
    do {
        ## This test is only for pairwise alignments!
        my $sequences;
        my $num_of_gaps = 0;
        foreach my $genomic_align (@{$genomic_align_block->genomic_align_array}) {
            $num_of_gaps += $genomic_align->cigar_line =~ tr/IDG/IDG/;
            push(@$sequences, $genomic_align->aligned_sequence);
        }
        my $lengths;
        my $this_length = 0;
        while ($sequences->[0]) {
            my $chr1 = substr($sequences->[0], 0, 1, "");
            my $chr2 = substr($sequences->[1], 0, 1, "");
            if ($chr1 eq "-" or $chr2 eq "-") {
                push(@$lengths, $this_length) if ($this_length);
                $this_length = 0;
            } else {
                $this_length++;
            }
        }
        push(@$lengths, $this_length) if ($this_length);

        my $ungapped_genomic_align_blocks = $genomic_align_block->get_all_ungapped_GenomicAlignBlocks();
        ## This GenomicAlignBlock contains 7 ungapped GenomicAlignBlocks
        is(scalar(@$ungapped_genomic_align_blocks), ($num_of_gaps+1),
           "Number of ungapped GenomicAlignBlocks (assuming normal pairwise alignments): ".$genomic_align_block->dbID);
        foreach my $ungapped_gab (@$ungapped_genomic_align_blocks) {
            my $this_length = shift @$lengths;
            ## This ok() is executed 7 times!!
            is($ungapped_gab->length, $this_length, "Ungapped GenomicAlignBlock has an unexpected length");
        }
    };
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->get_all_ungapped_GenomicAlignBlocks method", sub {
    my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
    
    do {
        my $ungapped_genomic_align_blocks = $genomic_align_block->get_all_ungapped_GenomicAlignBlocks();
        my $new_gab = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                                                                   -UNGAPPED_GENOMIC_ALIGN_BLOCKS => $ungapped_genomic_align_blocks
                                                                  );
        is(scalar(@{$new_gab->get_all_GenomicAligns}), scalar(@{$genomic_align_block->get_all_GenomicAligns}),
           "New from ungapped: Comparing original and resulting number of GenonimAligns");
        is($new_gab->length, $genomic_align_block->length,
           "New from ungapped: Comparing original and resulting lengh of alignments");
        is($new_gab->method_link_species_set_id, $genomic_align_block->method_link_species_set_id,
           "New from ungapped: Comparing original and resulting method_link_species_set_id");
        my $dnafrag_id = $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_id;
        my $new_ga;
        foreach my $genomic_align (@{$new_gab->get_all_GenomicAligns}) {
            $new_ga = $genomic_align if ($genomic_align->dnafrag_id == $dnafrag_id);
        }
        is($dnafrag_id, $new_ga->dnafrag_id,
           "New from ungapped: Comparing first dnafrag_id");
        is($genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence, $new_ga->aligned_sequence,
           "New from ungapped: Comparing first aligned_sequence");
    };
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->restrict_between_reference_positions method", sub {
    my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);

    do {
        my $length = length($genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence);
        my $cigar_line = $genomic_align_block->get_all_GenomicAligns->[0]->cigar_line;
        my ($match, $gap) = $cigar_line =~ /^(\d*)M(\d*)D/; ## This test asumes the alignment starts with a match on the forward strand...
        
        $match = 1 if (!$match);
        $gap = 1 if (!$gap);
        $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
        my $restricted_genomic_align_block = $genomic_align_block->restrict_between_reference_positions(
                                                                                                        $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start + $match - 1,
                                                                                                        $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end,
          $genomic_align_block->get_all_GenomicAligns->[0]
                                                                                                       );
        is(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match - 1, $length);
        
        $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
        $restricted_genomic_align_block = $genomic_align_block->restrict_between_reference_positions(
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start + $match,
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end,
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]
                                                                                                    );
        is(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match + $gap, $length);
        
        $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
        $restricted_genomic_align_block = $genomic_align_block->restrict_between_reference_positions(
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start + $match - 1,
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end,
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]
                                                                                                    );
        $restricted_genomic_align_block = $restricted_genomic_align_block->restrict_between_reference_positions(
                                                                                                                $restricted_genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start + 1,
                                                                                                                $restricted_genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end,
                                                                                                                $restricted_genomic_align_block->get_all_GenomicAligns->[0]
                                                                                                               );
        is(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match + $gap, $length);
        
        ($gap, $match) = $cigar_line =~ /(\d*)D(\d*)M$/; ## This test asumes the alignment ends with a match...
        $match = 1 if (!$match);
        $gap = 1 if (!$gap);
        $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
        $restricted_genomic_align_block = $genomic_align_block->restrict_between_reference_positions(
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start,
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end - $match + 1,
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]
                                                                                                    );
        is(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match - 1, $length);
        
        $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
        $restricted_genomic_align_block = $genomic_align_block->restrict_between_reference_positions(
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start,
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end - $match,
                                                                                                     $genomic_align_block->get_all_GenomicAligns->[0]
      );
        is(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match + $gap, $length);
        
        $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  $restricted_genomic_align_block = $genomic_align_block->restrict_between_reference_positions(
                                                                                               $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start,
                                                                                               $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end - $match + 1,
                                                                                               $genomic_align_block->get_all_GenomicAligns->[0]
                                                                                              );
        $restricted_genomic_align_block = $restricted_genomic_align_block->restrict_between_reference_positions(
                                                                                                                $restricted_genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start,
                                                                                                                $restricted_genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end - 1,
                                                                                                                $restricted_genomic_align_block->get_all_GenomicAligns->[0]
                                                                                                               );
        is(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match + $gap, $length);
        # Check the length of the original genomic_align (shouldn't have changed)
        is(length($genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence), $length);
    
    };
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignBlock->genomic_align_array(0) method [free GenomicAligns]", sub {
    my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
    $genomic_align_block->reference_genomic_align($genomic_align_block->get_all_GenomicAligns->[0]) ;
    is($genomic_align_block->reference_genomic_align(), $genomic_align_block->get_all_GenomicAligns->[0]);
    is($genomic_align_block->reference_genomic_align_id, $genomic_align_block->get_all_GenomicAligns->[0]->dbID);
    $genomic_align_block->genomic_align_array(0) ;
    is($genomic_align_block->{reference_genomic_align}, undef);
    is($genomic_align_block->{genomic_align_array}, undef);
    is($genomic_align_block->reference_genomic_align_id, $genomic_align_block->get_all_GenomicAligns->[0]->dbID);
    #is($genomic_align_block->reference_genomic_align);
    #is($genomic_align_block->genomic_align_array);

    done_testing();
};


done_testing();

