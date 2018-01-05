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

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

my $this_species = "homo_sapiens";

my $species = [
        "homo_sapiens",
    ];

## Connect to core DB specified in the MultiTestDB.conf file
my $genome_dbs;
my @test_dbs;
foreach my $this_species (@$species) {
    my $species_db = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
    my $species_db_adaptor = $species_db->get_DBAdaptor('core');
    my $species_gdb = $genome_db_adaptor->fetch_by_registry_name($this_species);
    $species_gdb->db_adaptor($species_db_adaptor);
    $genome_dbs->{$this_species} = $species_gdb;
    push @test_dbs, $species_db;
}

##
#####################################################################
  
my $genomic_align;
my $all_genomic_aligns;
my $genomic_align_adaptor = $compara_db_adaptor->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_db_adaptor->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_db_adaptor->get_MethodLinkSpeciesSetAdaptor();
my $dnafrag_adaptor = $compara_db_adaptor->get_DnaFragAdaptor();
my $genomeDB_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();
my $fail;

my $sth;
$sth = $compara_db_adaptor->dbc->prepare("SELECT
      genomic_align_id, genomic_align_block_id, method_link_species_set_id, dnafrag_id,
      dnafrag_start, dnafrag_end, dnafrag_strand, cigar_line, visible, node_id
    FROM genomic_align JOIN dnafrag USING (dnafrag_id) JOIN genome_db gdb USING (genome_db_id) WHERE gdb.name = '$this_species' AND dnafrag_strand = 1 AND cigar_line like \"\%D\%\" LIMIT 1");
$sth->execute();
my ($dbID, $genomic_align_block_id, $method_link_species_set_id, $dnafrag_id,
    $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line, $visible, $node_id) =
    $sth->fetchrow_array();
$sth->finish();

my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
my $method_link_species_set =
    $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);

my $aligned_sequence = "AAGGTCCCTAGTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCT-AACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGGCAAGTTCAAGGCCACTGCTTCCACTAGCAGAGAGGTGGTTGAGGTTCCTCCCAGTCACCACAGAGAAGATTTAACAAGTAAAAACCTGCAAACTCTTTATTAAATTCTCCCATTTCATCTGTACAGAAAAAAATGCACATTATGTTCAGAACATATCTCAGTAACATCTCAAAATTACACAGCATGAACATGTAAAAACAAGGGACCACCACGATTTTATACATAGAAAGGAAACCCATTTACAAAAGAGGCTTGTTAATTGTATTTTTTTCTTTCTTTCAAAAACAAAA---CAAAACAAAAA-AAGTGAAAAGCCTAAGATCTCACACAGCATTTGCTGTACAGACTGTTTTCCGGATGGACTGGTTTGGGAACACTGTGCTGGGGGAAGCTGCCCAGGAAGCGCTCCCGCTGC---CGGCTTTCCGGAGGTCTCTGCCCAGTGCACTGCAGGGGGACCTGGAGGGCCCATTTCTACCACCCTAGCATGTCTGACAGAAAGCCCTGCTGGGCTCTGGGGTCCAGATGTCAACTCTACATTGGAGGAGGCAAAACACAATCTAGAGGCA----CTGTCTGAACTTTCCCCTGGCCCAGGGAGATTTCTCCACTGCACACAGCACAGTGTCCTATACATGTGTCCTGGTGGAGCAGAGGGA-GCGGGAGAGGACC---ACGGGTCAGGATCCTGTCACCACCAGCCTGAGCAGACAGTCCCATCTTTGTGATCCAGGTGACAAATAATCAGTCCCTG-GTCCCCACAATGACCTCACCAGATGGCTTTGGGGAGCTCTTCACCCTAAAGATTCGGTCTGGTTTGCTAATGACTTATCTATTATCTGAAGTCTGTGGAGGAAG";

my $original_sequence = "AAGGTCCCTAGTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGGCAAGTTCAAGGCCACTGCTTCCACTAGCAGAGAGGTGGTTGAGGTTCCTCCCAGTCACCACAGAGAAGATTTAACAAGTAAAAACCTGCAAACTCTTTATTAAATTCTCCCATTTCATCTGTACAGAAAAAAATGCACATTATGTTCAGAACATATCTCAGTAACATCTCAAAATTACACAGCATGAACATGTAAAAACAAGGGACCACCACGATTTTATACATAGAAAGGAAACCCATTTACAAAAGAGGCTTGTTAATTGTATTTTTTTCTTTCTTTCAAAAACAAAACAAAACAAAAAAAGTGAAAAGCCTAAGATCTCACACAGCATTTGCTGTACAGACTGTTTTCCGGATGGACTGGTTTGGGAACACTGTGCTGGGGGAAGCTGCCCAGGAAGCGCTCCCGCTGCCGGCTTTCCGGAGGTCTCTGCCCAGTGCACTGCAGGGGGACCTGGAGGGCCCATTTCTACCACCCTAGCATGTCTGACAGAAAGCCCTGCTGGGCTCTGGGGTCCAGATGTCAACTCTACATTGGAGGAGGCAAAACACAATCTAGAGGCACTGTCTGAACTTTCCCCTGGCCCAGGGAGATTTCTCCACTGCACACAGCACAGTGTCCTATACATGTGTCCTGGTGGAGCAGAGGGAGCGGGAGAGGACCACGGGTCAGGATCCTGTCACCACCAGCCTGAGCAGACAGTCCCATCTTTGTGATCCAGGTGACAAATAATCAGTCCCTGGTCCCCACAATGACCTCACCAGATGGCTTTGGGGAGCTCTTCACCCTAAAGATTCGGTCTGGTTTGCTAATGACTTATCTATTATCTGAAGTCTGTGGAGGAAG";


subtest "Test Bio::EnsEMBL::Compara::GenomicAlign new(void) method", sub {
  my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign();
  isa_ok($genomic_align, "Bio::EnsEMBL::Compara::GenomicAlign", "check object");
  done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlign new(ALL) method", sub {

    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                             -adaptor => $genomic_align_adaptor,
                                                             -dbID => $dbID,
                                                             -genomic_align_block => $genomic_align_block,
                                                             -method_link_species_set => $method_link_species_set,
                                                             -dnafrag => $dnafrag,
                                                             -dnafrag_start => $dnafrag_start,
                                                             -dnafrag_end => $dnafrag_end,
                                                             -dnafrag_strand => $dnafrag_strand,
                                                             -visible => $visible,
                                                             -node_id => $node_id,
                                                             -cigar_line => $cigar_line
                                                            );
    is($genomic_align->adaptor, $genomic_align_adaptor, "adaptor");
    is($genomic_align->dbID, $dbID, "dbID");
    is($genomic_align->genomic_align_block, $genomic_align_block, "genomic_align_block");
    is($genomic_align->genomic_align_block_id, $genomic_align_block_id, "genomic_align_block_id");
    is($genomic_align->method_link_species_set, $method_link_species_set, "method_link_species_set");
    is($genomic_align->method_link_species_set_id, $method_link_species_set_id, "method_link_species_set_id");
    is($genomic_align->dnafrag, $dnafrag, "dnafrag");
    is($genomic_align->dnafrag_id, $dnafrag_id, "dnafrag_id");
    is($genomic_align->dnafrag_start, $dnafrag_start, "dnafrag_start");
    is($genomic_align->dnafrag_end, $dnafrag_end, "dnafrag_end");
    is($genomic_align->dnafrag_strand, $dnafrag_strand, "dnafrag_strand");
    is($genomic_align->visible, $visible, "visible");
    is($genomic_align->node_id, $node_id, "node_id");
    is($genomic_align->cigar_line, $cigar_line, "cigar_line");

    is($genomic_align->genomic_align_block->dbID, $genomic_align_block_id, "genomic_align_block->dbID");
    is($genomic_align->genomic_align_block_id, $genomic_align_block_id, "Trying to get object genomic_align_block_id from object");

    is($genomic_align->method_link_species_set->dbID, $method_link_species_set_id, "Trying to get method_link_species_set object from genomic_align_block");
    
    is_deeply($genomic_align->genome_db, $genome_dbs->{$this_species}, "genome_db");

    done_testing();
};

subtest "Test getter/setter Bio::EnsEMBL::Compara::GenomicAlign methods", sub {
    #my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign();

    #Need the populated object or the test_getter_setter module will return warnings 
    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                                -adaptor => $genomic_align_adaptor,
                                                                -dbID => $dbID,
                                                                -genomic_align_block => $genomic_align_block,
                                                                -method_link_species_set => $method_link_species_set,
                                                                -dnafrag => $dnafrag,
                                                                -dnafrag_start => $dnafrag_start,
                                                                -dnafrag_end => $dnafrag_end,
                                                                -dnafrag_strand => $dnafrag_strand,
                                                                -visible => $visible,
                                                                -node_id => $node_id,
                                                                -cigar_line => $cigar_line
                                                               );

    ok(test_getter_setter($genomic_align, "adaptor", $genomic_align_adaptor));
    ok(test_getter_setter($genomic_align, "dbID", $dbID));
    ok(test_getter_setter($genomic_align, "genomic_align_block", $genomic_align_block));
    ok(test_getter_setter($genomic_align, "genomic_align_block_id", $genomic_align_block_id));
    ok(test_getter_setter($genomic_align, "method_link_species_set", $method_link_species_set));
    ok(test_getter_setter($genomic_align, "method_link_species_set_id", $method_link_species_set_id));
    ok(test_getter_setter($genomic_align, "dnafrag", $dnafrag));
    ok(test_getter_setter($genomic_align, "dnafrag_start", $dnafrag_start));
    ok(test_getter_setter($genomic_align, "dnafrag_end", $dnafrag_end));
    ok(test_getter_setter($genomic_align, "dnafrag_strand", $dnafrag_strand));
    ok(test_getter_setter($genomic_align, "visible", $visible));
    ok(test_getter_setter($genomic_align, "node_id", $node_id));
    ok(test_getter_setter($genomic_align, "cigar_line", $cigar_line));

    done_testing();
};

subtest "Test throw conditions", sub {
    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                                -adaptor => $genomic_align_adaptor,
                                                                -dbID => $dbID,
                                                                -genomic_align_block_id => $genomic_align_block_id + 1
                                                               );
    
    is(eval{$genomic_align->genomic_align_block($genomic_align_block)}, undef, "Testing throw condition");
    is(eval{$genomic_align->genomic_align_block_id($genomic_align_block_id + 1)}, undef, "Testing throw condition");
    done_testing();
};

subtest "Test dnafrag throw conditions", sub {
    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                                -adaptor => $genomic_align_adaptor,
                                                                -dbID => $dbID,
                                                                -dnafrag_id => $dnafrag_id + 1
                                                            );
   is(eval{$genomic_align->dnafrag($dnafrag)}, undef,"Testing throw condition");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlign::copy", sub {
    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                             -adaptor => $genomic_align_adaptor,
                                                             -dbID => $dbID,
                                                             -genomic_align_block => $genomic_align_block,
                                                             -method_link_species_set => $method_link_species_set,
                                                             -dnafrag => $dnafrag,
                                                             -dnafrag_start => $dnafrag_start,
                                                             -dnafrag_end => $dnafrag_end,
                                                             -dnafrag_strand => $dnafrag_strand,
                                                             -visible => $visible,
                                                             -node_id => $node_id,
                                                             -cigar_line => $cigar_line
                                                            );
    my $new_genomic_align = $genomic_align->copy;

    is_deeply($genomic_align, $new_genomic_align, "Test copy");
    done_testing();

};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlign::original_sequence method", sub {
    my $original_sequence = "AAGGTCCCTAGTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    my $cigar_line = "10M3D90M";
    my $aligned_sequence = "AAGGTCCCTA---GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    my $length = 103;

    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                                -dnafrag => $dnafrag,
                                                                -dnafrag_start => 1,
                                                                -dnafrag_end => 100,
                                                                -dnafrag_strand => 1,
                                                               );
    #Need to set this separately
    $genomic_align->aligned_sequence($aligned_sequence);
    is($genomic_align->original_sequence, $original_sequence, "Trying to get original_sequence from aligned_sequence");
    is($genomic_align->length, $length, "length");
    done_testing();

};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlign::aligned_sequence method", sub {
    my $original_sequence = "AAGGTCCCTAGTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    my $cigar_line = "10M3D90M";
    my $aligned_sequence = "AAGGTCCCTA---GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    my $length = 103;

    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                                -dnafrag => $dnafrag,
                                                                -dnafrag_start => 1,
                                                                -dnafrag_end => 100,
                                                                -dnafrag_strand => 1,
                                                                -cigar_line => $cigar_line,
                                                               );
    #Need to set this separately since original_sequence is not an option for new GenomicAlign
    $genomic_align->original_sequence($original_sequence);
    is($genomic_align->aligned_sequence, $aligned_sequence, "Trying to get aligned_sequence from original_sequence and cigar_line");
    is($genomic_align->length, $length, "length");

    #D at the beginning
    $genomic_align->aligned_sequence("");
    $cigar_line = "3D10M3D90M";
    $aligned_sequence = "---AAGGTCCCTA---GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    $length = 106;
    $genomic_align->cigar_line($cigar_line);
    is($genomic_align->aligned_sequence, $aligned_sequence, "Trying to get aligned_sequence from original_sequence and cigar_line: D at beginning");
    is($genomic_align->length, $length, "length");

    #D at the end 
    $genomic_align->aligned_sequence("");
    $cigar_line = "10M3D90M3D";
    $aligned_sequence = "AAGGTCCCTA---GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG---";
    $length = 106;
    $genomic_align->cigar_line($cigar_line);
    is($genomic_align->aligned_sequence, $aligned_sequence, "Trying to get aligned_sequence from original_sequence and cigar_line: D at end");
    is($genomic_align->length, $length, "length");

    #X    
    $genomic_align->aligned_sequence("");
    $cigar_line = "10M3X90M";
    $aligned_sequence = "AAGGTCCCTA...GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    $length = 103;
    $genomic_align->cigar_line($cigar_line);
    is($genomic_align->aligned_sequence, $aligned_sequence, "Trying to get aligned_sequence from original_sequence and cigar_line: X");
    is($genomic_align->length, $length, "length");

    #X at the beginning
    $genomic_align->aligned_sequence("");
    $cigar_line = "3X10M3X90M";
    $aligned_sequence = "...AAGGTCCCTA...GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    $genomic_align->cigar_line($cigar_line);
    is($genomic_align->aligned_sequence, $aligned_sequence, "Trying to get aligned_sequence from original_sequence and cigar_line: X at beginning");

    #X at the end
    $genomic_align->aligned_sequence("");
    $cigar_line = "10M3X90M3X";
    $aligned_sequence = "AAGGTCCCTA...GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG...";
    $genomic_align->cigar_line($cigar_line);
    is($genomic_align->aligned_sequence, $aligned_sequence, "Trying to get aligned_sequence from original_sequence and cigar_line: X at end");

    #I
    $genomic_align->aligned_sequence("");
    $cigar_line = "10M3I3D87M";
    $aligned_sequence = "AAGGTCCCTA---CTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    $length = 100;
    $genomic_align->cigar_line($cigar_line);
    is($genomic_align->aligned_sequence, $aligned_sequence, "Trying to get aligned_sequence from original_sequence and cigar_line: I");
    is($genomic_align->length, $length, "length");


    #I at the beginning
    $genomic_align->aligned_sequence("");
    $cigar_line = "3I7M3D90M";
    $aligned_sequence = "GTCCCTA---GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    $genomic_align->cigar_line($cigar_line);
    is($genomic_align->aligned_sequence, $aligned_sequence, "Trying to get aligned_sequence from original_sequence and cigar_line: I at beginning");

    #I at the end
    $genomic_align->aligned_sequence("");
    $cigar_line = "10M3D87M3I";
    $aligned_sequence = "AAGGTCCCTA---GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGT";
    $genomic_align->cigar_line($cigar_line);
    is($genomic_align->aligned_sequence, $aligned_sequence, "Trying to get aligned_sequence from original_sequence and cigar_line: I at end");

    #FIX_SEQ and FAKE_SEQ
    #D at the beginning
    $genomic_align->aligned_sequence("");
    $cigar_line = "10M3D90M";
    $aligned_sequence = "AAGGTCCCTA---GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    $genomic_align->cigar_line($cigar_line);
    #is($genomic_align->aligned_sequence("+FIX_SEQ"), $aligned_sequence, "Trying to get aligned_sequence from original_sequence and cigar_line: D at beginning");


    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlign::cigar_line method", sub {
    my $original_sequence = "AAGGTCCCTAGTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    my $cigar_line = "10M3D90M";
    my $aligned_sequence = "AAGGTCCCTA---GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    
    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                                -adaptor => $genomic_align_adaptor,
                                                                -dbID => $dbID,
#                                                                -aligned_sequence => $aligned_sequence,
                                                               );
    $genomic_align->aligned_sequence($aligned_sequence);

    is($genomic_align->cigar_line, $cigar_line, "Trying to get cigar_line from aligned_sequence");
    is($genomic_align->original_sequence, $original_sequence, "Trying to get original_sequence from aligned_sequence");

    #Need to add X and I
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlign::display_id", sub {
    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                                -adaptor => $genomic_align_adaptor,
                                                                -dbID => $dbID,
                                                                -aligned_sequence => $aligned_sequence,
                                                               );

    my $this_display_id = join ':', $genome_dbs->{$this_species}->taxon_id, $genome_dbs->{$this_species}->dbID, $dnafrag->coord_system_name, $dnafrag->name, $dnafrag_start, $dnafrag_end, $dnafrag_strand;

    is($genomic_align->display_id, $this_display_id, "display_id");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlign:reverse_complement method", sub {
    my $original_sequence = "AAGGTCCCTAGT";
    my $rev_sequence = "ACTAGGGACCTT";
    my $cigar_line = "7M3D5M";
    my $rev_cigar_line = "5M3D7M";
    my $rev_aligned_sequence = "ACTAG---GGACCTT";
    
    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                                -dnafrag => $dnafrag,
                                                                -dnafrag_start => 1,
                                                                -dnafrag_end => 100,
                                                                -dnafrag_strand => 1,
                                                                -cigar_line => $cigar_line,
                                                                );
    #Need to set this separately since original_sequence is not an option for new GenomicAlign
    $genomic_align->original_sequence($original_sequence);

    $genomic_align->reverse_complement();
    is($genomic_align->original_sequence, $rev_sequence, 'reverse original_sequence');
    is($genomic_align->cigar_line, $rev_cigar_line, 'reverse cigar_line');
    is($genomic_align->aligned_sequence, $rev_aligned_sequence, 'reverse aligned_sequence');
    
    done_testing();
};

#Not sure how to test this.
subtest "Test Bio::EnsEMBL::Compara::GenomicAlign:get_Mapper method", sub {
    my $original_sequence = "AAGGTCCCTAGTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    my $cigar_line = "10M3D90M";

    #taken from the cigar_line
    my $these_coords;
    push @$these_coords, (1,10);
    push @$these_coords, (14,103);

    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                                -dnafrag => $dnafrag,
                                                                -dnafrag_start => 1,
                                                                -dnafrag_end => 100,
                                                                -dnafrag_strand => 1,
                                                                -cigar_line => $cigar_line,
                                                               );

    my $mapper = $genomic_align->get_Mapper();

    my @coords = $mapper->map_coordinates("sequence",
                                          1,
                                          100,
                                          1,
                                          "sequence");

    my $i = 0;
    foreach my $coord (@coords) {
        is($coord->start, $these_coords->[$i++]);
        is($coord->end, $these_coords->[$i++]);
    }
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlign::get_Slice method",  sub {
    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                                -adaptor => $genomic_align_adaptor,
                                                                -dbID => $dbID,
                                                                -genomic_align_block => $genomic_align_block,
                                                                -method_link_species_set => $method_link_species_set,
                                                                -dnafrag => $dnafrag,
                                                                -dnafrag_start => $dnafrag_start,
                                                                -dnafrag_end => $dnafrag_end,
                                                                -dnafrag_strand => $dnafrag_strand,
                                                                -visible => $visible,
                                                                -node_id => $node_id,
                                                                -cigar_line => $cigar_line
                                                               );
    my $slice = $genomic_align->get_Slice;

    is($slice->coord_system->name, $dnafrag->coord_system_name, "slice coord_syste");
    is($slice->start, $genomic_align->dnafrag_start, "slice start");
    is($slice->end, $genomic_align->dnafrag_end, "slice end");
    is($slice->strand, $genomic_align->dnafrag_strand, "slice strand");
    is($slice->seq_region_length, $dnafrag->length, "slice length");
    is($slice->seq_region_name,, $dnafrag->name, "slice seq_region_name");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlign::restrict", sub {
    my $original_sequence = "AAGGTCCCTAGTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    my $cigar_line = "10M3D90M";
    my $aligned_sequence = "AAGGTCCCTA---GTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGG";
    my $length = 103; #alignment coords
    my $dnafrag_start = 1;
    my $dnafrag_end = 100;
    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                                                                -dnafrag => $dnafrag,
                                                                -dnafrag_start => $dnafrag_start,
                                                                -dnafrag_end => $dnafrag_end,
                                                                -dnafrag_strand => 1,
                                                                -cigar_line => $cigar_line,
                                                               );
    #Need to set this separately since original_sequence is not an option for new GenomicAlign
    $genomic_align->original_sequence($original_sequence);

    #Trim 2 bases off start and end ie start at position 3
    my $offset = 3;
    my $start = $offset; 
    my $end = ($length - $offset); 
    my $res_cigar_line = "8M3D87M";

    my $restricted_ga = $genomic_align->restrict($start, $end);
    is($restricted_ga->cigar_line, $res_cigar_line, "restricted cigar_line");
    is($restricted_ga->dnafrag_start, ($dnafrag_start+$offset-1), "restricted start");
    is($restricted_ga->dnafrag_end, ($dnafrag_end-$offset), "restricted end");

    #Trim 9 bases off start and end ie start at position 10
    $offset = 10;
    $start = $offset; 
    $end = ($length - $offset); 
   $res_cigar_line = "M3D80M";

    $restricted_ga = $genomic_align->restrict($start, $end);
    is($restricted_ga->cigar_line, $res_cigar_line, "restricted cigar_line");
    is($restricted_ga->dnafrag_start, ($dnafrag_start+$offset-1), "restricted start");
    is($restricted_ga->dnafrag_end, ($dnafrag_end-$offset), "restricted end");

    #Trim 10 positions off start and end ie start at position 11
    $offset = 11;
    $start = $offset; 
    $end = ($length - $offset); 
   $res_cigar_line = "3D79M";

    $restricted_ga = $genomic_align->restrict($start, $end);
    is($restricted_ga->cigar_line, $res_cigar_line, "restricted cigar_line");
    is($restricted_ga->dnafrag_start, ($dnafrag_start+$offset-1), "restricted start");
    is($restricted_ga->dnafrag_end, ($dnafrag_end-$offset), "restricted end");

    #Trim 11 positions off start and end ie start at position 12
    $offset = 12;
    $start = $offset; 
    $end = ($length - $offset); 
    $res_cigar_line = "2D78M";

    $restricted_ga = $genomic_align->restrict($start, $end);
    is($restricted_ga->cigar_line, $res_cigar_line, "restricted cigar_line");
    is($restricted_ga->dnafrag_start, ($dnafrag_start+$offset-1-1), "restricted start");
    is($restricted_ga->dnafrag_end, ($dnafrag_end-$offset), "restricted end");

    #Need to test X and I
    $cigar_line = "10M3X90M";
    $genomic_align->cigar_line($cigar_line);
    $offset = 12;
    $start = $offset; 
    $end = ($length - $offset); 
    $res_cigar_line = "2X78M";

    $restricted_ga = $genomic_align->restrict($start, $end);
    is($restricted_ga->cigar_line, $res_cigar_line, "restricted cigar_line X");
    is($restricted_ga->dnafrag_start, ($dnafrag_start+$offset-1-1), "restricted start");
    is($restricted_ga->dnafrag_end, ($dnafrag_end-$offset), "restricted end");

    $cigar_line = "10M3I90M";
    $genomic_align->cigar_line($cigar_line);
    $offset = 12; 
    $start = $offset; 
    $end = 100; 
    $res_cigar_line = "89M"; #skips over the 3I and takes one off the 90M

    $restricted_ga = $genomic_align->restrict($start, $end);
    is($restricted_ga->cigar_line, $res_cigar_line, "restricted cigar_line I");
    is($restricted_ga->dnafrag_start, ($dnafrag_start+$offset-1+3), "restricted start");
    is($restricted_ga->dnafrag_end, $dnafrag_end, "restricted end");

    done_testing();
};

done_testing();

