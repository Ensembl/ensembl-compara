#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::GenomicAlignBlock module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

genomicAlignBlock.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl genomicAlignBlock.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::GenomicAlignBlock module.

This script includes 73 tests.

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2004. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=cut



use strict;

BEGIN { $| = 1;  
    use Test;
    plan tests => 73;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

my $species = [
        "homo_sapiens",
#         "mus_musculus",
        "rattus_norvegicus",
        "gallus_gallus",
    ];

my $species_db;
my $species_db_adaptor;
my $species_gdb;
## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (@$species) {
  $species_db->{$this_species} = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  die if (!$species_db->{$this_species});
  $species_db_adaptor->{$this_species} = $species_db->{$this_species}->get_DBAdaptor('core');
  $species_gdb->{$this_species} = $genome_db_adaptor->fetch_by_name_assembly(
          $species_db_adaptor->{$this_species}->get_MetaContainer->get_Species->binomial,
          $species_db_adaptor->{$this_species}->get_CoordSystemAdaptor->fetch_all->[0]->version
      );
  $species_gdb->{$this_species}->db_adaptor($species_db_adaptor->{$this_species});
}

##
#####################################################################

# switch off the debug prints 
our $verbose = 0;

# my $genomic_align;
# my $all_genomic_aligns;
my $genomic_align_adaptor = $compara_db_adaptor->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_db_adaptor->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_db_adaptor->get_MethodLinkSpeciesSetAdaptor();
# my $dnafrag_adaptor = $compara_db->get_DnaFragAdaptor();
# my $genomeDB_adaptor = $compara_db->get_GenomeDBAdaptor();
# my $fail;
# 
# my $dbID = 7279606;
# my $genomic_align_block_id = 3639804;
# my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
# my $dnafrag_id = 19;
# my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
# my $dnafrag_start = 50007134;
# my $dnafrag_end = 50007289;
# my $dnafrag_strand = 1;
# my $level_id = 1;
# my $cigar_line = "15MG78MG63M";
# my $aligned_sequence = "TCATTGGCTCATTTT-ATTGCATTCAATGAATTGTTGGAAATTAGAGCCAGCCAAAAATTGTATAAATATTGGGCTGTGTCTGCTTCTCTGACA-CTAGATGAAGATGGCATTTGTGCCTGTGTGTCTGTGGGGTCCTCAGGAAGCTCTTCTCCTTGA";
# my $original_sequence = "TCATTGGCTCATTTTATTGCATTCAATGAATTGTTGGAAATTAGAGCCAGCCAAAAATTGTATAAATATTGGGCTGTGTCTGCTTCTCTGACACTAGATGAAGATGGCATTTGTGCCTGTGTGTCTGTGGGGTCCTCAGGAAGCTCTTCTCCTTGA";

my $genomic_align_blocks;
my $genomic_align_block;
my $genomic_align_block_id = 5857270;
my $method_link_species_set_id = 72;
my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
my $score = 4581;
my $perc_id = 48;
my $length = 283;
my $genomic_algin_1_dbID = 11714534;
my $genomic_align_1 = $genomic_align_adaptor->fetch_by_dbID($genomic_algin_1_dbID);
my $genomic_algin_2_dbID = 11714544;
my $genomic_align_2 = $genomic_align_adaptor->fetch_by_dbID($genomic_algin_2_dbID);
my $genomic_align_array = [$genomic_align_1, $genomic_align_2];
die if (!$species_db);
print STDERR $species_db;
my $slice_adaptor = $species_db->{"homo_sapiens"}->get_DBAdaptor("core")->get_SliceAdaptor();
my $slice_coord_system_name = "chromosome";
my $slice_seq_region_name = "14";
my $slice_start = 50000000;
my $slice_end = 50001000;

# 
# 1
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->new(void) method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  ok($genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));

# 
# 2-9
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->new(ALL) method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
          -method_link_species_set => $method_link_species_set,
          -score => $score,
          -length => $length,
          -genomic_align_array => $genomic_align_array
      );
  ok($genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));
  ok($genomic_align_block->adaptor, $genomic_align_block_adaptor);
  ok($genomic_align_block->dbID, $genomic_align_block_id);
  ok($genomic_align_block->method_link_species_set, $method_link_species_set);
  ok($genomic_align_block->score, $score);
  ok($genomic_align_block->length, $length);
  ok($genomic_align_block->genomic_align_array, $genomic_align_array);

# 
# 9
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->adaptor method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->adaptor($genomic_align_block_adaptor);
  ok($genomic_align_block->adaptor, $genomic_align_block_adaptor);

# 
# 10
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->dbID method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->dbID($genomic_align_block_id);
  ok($genomic_align_block->dbID, $genomic_align_block_id);

# 
# 11
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->method_link_species_set method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->method_link_species_set($method_link_species_set);
  ok($genomic_align_block->method_link_species_set, $method_link_species_set);

# 
# 12
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->method_link_species_set method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -method_link_species_set_id => $method_link_species_set_id,
      );
  ok($genomic_align_block->method_link_species_set->dbID, $method_link_species_set_id,
      "Trying to get method_link_species_set object from method_link_species_set_id");

# 
# 13
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->method_link_species_set_id method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->method_link_species_set_id($method_link_species_set_id);
  ok($genomic_align_block->method_link_species_set_id, $method_link_species_set_id);

# 
# 14
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->method_link_species_set_id method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->method_link_species_set_id($method_link_species_set_id);
  ok($genomic_align_block->method_link_species_set_id, $method_link_species_set_id);

# 
# 15
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->method_link_species_set_id method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -method_link_species_set => $method_link_species_set,
      );
  ok($genomic_align_block->method_link_species_set_id, $method_link_species_set_id,
      "Trying to get method_link_species_set_id from method_link_species_set object");

# 
# 16
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->method_link_species_set_id method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  ok($genomic_align_block->method_link_species_set_id, $method_link_species_set_id,
      "Trying to get method_link_species_set_id from the database");

# 
# 17
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_genomic_align_id method");
  verbose("EXCEPTION");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  $genomic_align_block->reference_genomic_align_id(0);
  ok($genomic_align_block->reference_genomic_align, undef);

# 
# 18
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_genomic_align method");
  my $slice = $slice_adaptor->fetch_by_region(
          $slice_coord_system_name,
          $slice_seq_region_name,
          $slice_start,
          $slice_end
      );
  $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_Slice(
          $method_link_species_set_id,
          $slice
      );
  ok($genomic_align_blocks->[0]->reference_genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlign"));

# 
# 19
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->get_all_non_reference_genomic_aligns method");
  my $first_reference_genomic_align_id = $genomic_align_blocks->[0]->reference_genomic_align->dbID;
  my $second_reference_genomic_align_id =
      $genomic_align_blocks->[0]->get_all_non_reference_genomic_aligns->[0]->dbID;
  $genomic_align_blocks->[0]->reference_genomic_align_id($second_reference_genomic_align_id);
  ok($genomic_align_blocks->[0]->reference_genomic_align->dbID, $second_reference_genomic_align_id);
  verbose("DEPRECATE");

# 
# 20
# 
foreach my $this_genomic_align (@$genomic_align_array) {
  $this_genomic_align->genomic_align_block_id(0);
}
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->genomic_align_array method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->genomic_align_array($genomic_align_array);
  ok($genomic_align_block->genomic_align_array, $genomic_align_array);

# 
# 21-22
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->genomic_align_array method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  ok(scalar(@{$genomic_align_block->genomic_align_array}), scalar(@{$genomic_align_array}),
      "Trying to get method_link_species_set_id from the database");
  do {
    my $all_fails;
    foreach my $this_genomic_align (@{$genomic_align_block->genomic_align_array}) {
      my $fail = $this_genomic_align->dbID;
      foreach my $that_genomic_align (@$genomic_align_array) {
        if ($that_genomic_align->dbID == $this_genomic_align->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
    }
    ok($all_fails, undef,
        "Trying to get method_link_species_set_id from the database (returns the unexpected genomic_align_id)");
  };


foreach my $this_genomic_align (@$genomic_align_array) {
  $this_genomic_align->genomic_align_block_id(0);
}
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->genomic_align_array method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  foreach my $this_genomic_align (@$genomic_align_array) {
    $genomic_align_block->add_GenomicAlign($this_genomic_align);
  }
  ok(@{$genomic_align_block->get_all_GenomicAligns}, @$genomic_align_array);


debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->genomic_align_array method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  ok(scalar(@{$genomic_align_block->get_all_GenomicAligns}), scalar(@{$genomic_align_array}),
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
    ok($all_fails, undef,
        "Trying to get method_link_species_set_id from the database (returns the unexpected genomic_align_id)");
  };

# 
# 23
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->score method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->score($score);
  ok($genomic_align_block->score, $score);

# 
# 24
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->score method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  ok($genomic_align_block->score, $score,
      "Trying to get score from the database");

# 
# 25
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->perc_id method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->perc_id($perc_id);
  ok($genomic_align_block->perc_id, $perc_id);

# 
# 26
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->score method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  ok($genomic_align_block->perc_id, $perc_id,
      "Trying to get perc_id from the database");

# 
# 27
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->length method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->length($length);
  ok($genomic_align_block->length, $length);

# 
# 28
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->length method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  ok($genomic_align_block->length, $length,
      "Trying to get length from the database");

# 
# 29
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice method");
  $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
          $method_link_species_set,
          $slice
      );
  ok($genomic_align_blocks->[0]->reference_slice, $slice);

# 
# 30
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice_start method");
  ok($genomic_align_blocks->[0]->reference_slice_start,
    $genomic_align_blocks->[0]->reference_genomic_align->dnafrag_start - $slice->start + 1);

# 
# 31
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice_start method");
  $genomic_align_blocks->[0]->reference_slice_start(0);
  ok($genomic_align_blocks->[0]->reference_slice_start, undef);

# 
# 32
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice_start method");
  $genomic_align_blocks->[0]->reference_slice_start(100);
  ok($genomic_align_blocks->[0]->reference_slice_start, 100);

# 
# 33
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice_end method");
  ok($genomic_align_blocks->[0]->reference_slice_end,
    $genomic_align_blocks->[0]->reference_genomic_align->dnafrag_end - $slice->start + 1);

# 
# 34
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice_end method");
  $genomic_align_blocks->[0]->reference_slice_end(0);
  ok($genomic_align_blocks->[0]->reference_slice_end, undef);

# 
# 35
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reference_slice_end method");
  $genomic_align_blocks->[0]->reference_slice_end(1000);
  ok($genomic_align_blocks->[0]->reference_slice_end, 1000);

# 
# 36
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->alignment_strings method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -dbID => $genomic_align_block_id,
          -adaptor => $genomic_align_block_adaptor
      );
  ok(scalar(@{$genomic_align_block->alignment_strings}), scalar(@{$genomic_align_array}));

# 
# 37-40
#
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->reverse_complement method");

$genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice
  ($method_link_species_set,
   $slice);

$genomic_align_block = $genomic_align_blocks->[0];
$genomic_align_array = $genomic_align_block->genomic_align_array;
$genomic_align_block->reverse_complement;

my $st = $genomic_align_block->reference_genomic_align;
ok( $st->dnafrag_strand, -1 );
ok( $st->cigar_line, "13M44D15M12D6M7D34MD63M2D86M");

my $res = $genomic_align_block->get_all_non_reference_genomic_aligns->[0];
ok( $res->dnafrag_strand == -1 );
ok( $res->cigar_line eq "142M14D127M");

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->get_all_ungapped_GenomicAlignBlocks method");
$genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice
  ($method_link_species_set,
   $slice);

$genomic_align_block = $genomic_align_blocks->[0];
do {
  ## This test is only for pairwise alignments!
  my $sequences;
  foreach my $genomic_align (@{$genomic_align_block->genomic_align_array}) {
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
  ok(scalar(@$ungapped_genomic_align_blocks), 7, "Number of ungapped GenomicAlignBlocks");
  foreach my $ungapped_gab (@$ungapped_genomic_align_blocks) {
    my $this_length = shift @$lengths;
    ## This ok() is executed 7 times!!
    ok($ungapped_gab->length, $this_length, "Ungapped GenomicAlignBlock has an unexpected length");
  }
};

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->get_all_ungapped_GenomicAlignBlocks method");
$genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);

do {
  my $ungapped_genomic_align_blocks = $genomic_align_block->get_all_ungapped_GenomicAlignBlocks();
  my $new_gab = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -UNGAPPED_GENOMIC_ALIGN_BLOCKS => $ungapped_genomic_align_blocks
      );
  ok(scalar(@{$new_gab->get_all_GenomicAligns}), scalar(@{$genomic_align_block->get_all_GenomicAligns}),
      "New from ungapped: Comparing original and resulting number of GenonimAligns");
  ok($new_gab->length, $genomic_align_block->length,
      "New from ungapped: Comparing original and resulting lengh of alignments");
  ok($new_gab->method_link_species_set_id, $genomic_align_block->method_link_species_set_id,
      "New from ungapped: Comparing original and resulting method_link_species_set_id");
  my $dnafrag_id = $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_id;
  my $new_ga;
  foreach my $genomic_align (@{$new_gab->get_all_GenomicAligns}) {
    $new_ga = $genomic_align if ($genomic_align->dnafrag_id == $dnafrag_id);
  }
  ok($dnafrag_id, $new_ga->dnafrag_id,
      "New from ungapped: Comparing first dnafrag_id");
  ok($genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence, $new_ga->aligned_sequence,
      "New from ungapped: Comparing first aligned_sequence");
};

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->restrict_between_reference_positions method");
$genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);

do {
  my $length = length($genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence);
  my $cigar_line = $genomic_align_block->get_all_GenomicAligns->[0]->cigar_line;
  my ($match, $gap) = $cigar_line =~ /^(\d*)M(\d*)D/; ## This test asumes the alignment starts with a match...
  $match = 1 if (!$match);
  $gap = 1 if (!$gap);
  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  my $restricted_genomic_align_block = $genomic_align_block->restrict_between_reference_positions(
          $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start + $match - 1,
          $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end,
          $genomic_align_block->get_all_GenomicAligns->[0]
      );
  ok(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match - 1, $length);

  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  $restricted_genomic_align_block = $genomic_align_block->restrict_between_reference_positions(
          $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start + $match,
          $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end,
          $genomic_align_block->get_all_GenomicAligns->[0]
      );
  ok(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match + $gap, $length);
    
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
  ok(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match + $gap, $length);

  ($gap, $match) = $cigar_line =~ /(\d*)D(\d*)M$/; ## This test asumes the alignment ends with a match...
  $match = 1 if (!$match);
  $gap = 1 if (!$gap);
  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  $restricted_genomic_align_block = $genomic_align_block->restrict_between_reference_positions(
          $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start,
          $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end - $match + 1,
          $genomic_align_block->get_all_GenomicAligns->[0]
      );
  ok(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match - 1, $length);

  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  $restricted_genomic_align_block = $genomic_align_block->restrict_between_reference_positions(
          $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_start,
          $genomic_align_block->get_all_GenomicAligns->[0]->dnafrag_end - $match,
          $genomic_align_block->get_all_GenomicAligns->[0]
      );
  ok(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match + $gap, $length);
    
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
  ok(length($restricted_genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence) + $match + $gap, $length);
  # Check the length of the original genomic_align (shouldn't have changed)
  ok(length($genomic_align_block->get_all_GenomicAligns->[0]->aligned_sequence), $length);
    
};


#####################################################################
## TEST DEPRECATED METHODS

do {

verbose("EXCEPTION");


debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->starting_genomic_align_id method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  $genomic_align_block->starting_genomic_align_id(0);
  ok($genomic_align_block->starting_genomic_align, undef);

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->starting_genomic_align method");
  my $slice = $slice_adaptor->fetch_by_region(
          $slice_coord_system_name,
          $slice_seq_region_name,
          $method_link_species_set_id,
          $slice
      );
  ok($genomic_align_blocks->[0]->starting_genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlign"));

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->resulting_genomic_aligns method");
  my $first_starting_genomic_align_id = $genomic_align_blocks->[0]->starting_genomic_align->dbID;
  my $second_starting_genomic_align_id = $genomic_align_blocks->[0]->resulting_genomic_aligns->[0]->dbID;
  $genomic_align_blocks->[0]->starting_genomic_align_id($second_starting_genomic_align_id);
  ok($genomic_align_blocks->[0]->starting_genomic_align->dbID, $second_starting_genomic_align_id);

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->requesting_slice method");
  $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
          $method_link_species_set,
          $slice
      );
  ok($genomic_align_blocks->[0]->requesting_slice, $slice);

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->requesting_slice_start method");
  ok($genomic_align_blocks->[0]->requesting_slice_start,
    $genomic_align_blocks->[0]->reference_genomic_align->dnafrag_start - $slice->start + 1);

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->requesting_slice_start method");
  $genomic_align_blocks->[0]->requesting_slice_start(0);
  ok($genomic_align_blocks->[0]->requesting_slice_start, undef);

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->requesting_slice_start method");
  $genomic_align_blocks->[0]->requesting_slice_start(100);
  ok($genomic_align_blocks->[0]->requesting_slice_start, 100);

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->requesting_slice_end method");
  ok($genomic_align_blocks->[0]->requesting_slice_end,
    $genomic_align_blocks->[0]->reference_genomic_align->dnafrag_end - $slice->start + 1);

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->requesting_slice_end method");
  $genomic_align_blocks->[0]->requesting_slice_end(0);
  ok($genomic_align_blocks->[0]->requesting_slice_end, undef);

debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock->requesting_slice_end method");
  $genomic_align_blocks->[0]->requesting_slice_end(1000);
  ok($genomic_align_blocks->[0]->requesting_slice_end, 1000);


};
exit 0;
