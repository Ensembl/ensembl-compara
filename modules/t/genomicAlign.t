#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::GenomicAlign module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

genomicAlign.t

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl genomicAlign.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::GenomicAlign module.

This script includes 40 tests.

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
    plan tests => 40;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

# switch off the debug prints 
our $verbose = 0;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");

my $compara_db = $multi->get_DBAdaptor( "compara" );
  
my $genomic_align;
my $all_genomic_aligns;
my $genomic_align_adaptor = $compara_db->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_db->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_db->get_MethodLinkSpeciesSetAdaptor();
my $dnafrag_adaptor = $compara_db->get_DnaFragAdaptor();
my $genomic_align_group_adaptor = $compara_db->get_GenomicAlignGroupAdaptor();
my $genomeDB_adaptor = $compara_db->get_GenomeDBAdaptor();
my $fail;

my $dbID = 7279606;
my $genomic_align_block_id = 3639804;
my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
my $method_link_species_set_id = 2;
my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
my $dnafrag_id = 19;
my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
my $dnafrag_start = 50007134;
my $dnafrag_end = 50007289;
my $dnafrag_strand = 1;
my $level_id = 1;
my $genomic_align_group_1_id = 1;
my $genomic_align_group_1_type = "default";
my $genomic_align_group_1 = $genomic_align_group_adaptor->fetch_by_dbID($genomic_align_group_1_id);
my $genomic_align_groups = [$genomic_align_group_1];
my $cigar_line = "15MG78MG63M";
my $aligned_sequence = "TCATTGGCTCATTTT-ATTGCATTCAATGAATTGTTGGAAATTAGAGCCAGCCAAAAATTGTATAAATATTGGGCTGTGTCTGCTTCTCTGACA-CTAGATGAAGATGGCATTTGTGCCTGTGTGTCTGTGGGGTCCTCAGGAAGCTCTTCTCCTTGA";
my $original_sequence = "TCATTGGCTCATTTTATTGCATTCAATGAATTGTTGGAAATTAGAGCCAGCCAAAAATTGTATAAATATTGGGCTGTGTCTGCTTCTCTGACACTAGATGAAGATGGCATTTGTGCCTGTGTGTCTGTGGGGTCCTCAGGAAGCTCTTCTCCTTGA";

# 
# 1
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign new(void) method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign();
  ok($genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlign"));

# 
# 2-14
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign new(ALL) method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -genomic_align_block => $genomic_align_block,
      -method_link_species_set => $method_link_species_set,
      -dnafrag => $dnafrag,
      -dnafrag_start => $dnafrag_start,
      -dnafrag_end => $dnafrag_end,
      -dnafrag_strand => $dnafrag_strand,
      -level_id => $level_id,
      -cigar_line => $cigar_line
      );
  ok($genomic_align->adaptor, $genomic_align_adaptor);
  ok($genomic_align->dbID, $dbID);
  ok($genomic_align->genomic_align_block, $genomic_align_block);
  ok($genomic_align->genomic_align_block_id, $genomic_align_block_id);
  ok($genomic_align->method_link_species_set, $method_link_species_set);
  ok($genomic_align->method_link_species_set_id, $method_link_species_set_id);
  ok($genomic_align->dnafrag, $dnafrag);
  ok($genomic_align->dnafrag_id, $dnafrag_id);
  ok($genomic_align->dnafrag_start, $dnafrag_start);
  ok($genomic_align->dnafrag_end, $dnafrag_end);
  ok($genomic_align->dnafrag_strand, $dnafrag_strand);
  ok($genomic_align->level_id, $level_id);
  ok($genomic_align->cigar_line, $cigar_line);

# 
# 15
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::genomic_align_block method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -genomic_align_block_id => $genomic_align_block_id
      );
  ok($genomic_align->genomic_align_block->dbID, $genomic_align_block_id,
          "Trying to get object from genomic_align_block_id");

# 
# 16
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::genomic_align_block_id method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -genomic_align_block => $genomic_align_block
      );
  ok($genomic_align->genomic_align_block_id, $genomic_align_block_id,
          "Trying to get object genomic_align_block_id from object");

# 
# 17
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::genomic_align_block_id method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->genomic_align_block_id, $genomic_align_block_id,
          "Trying to get object genomic_align_block_id from the database");

# 
# 18
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::method_link_species_set method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -genomic_align_block => $genomic_align_block,
      );
  ok($genomic_align->method_link_species_set->dbID, $method_link_species_set_id,
          "Trying to get method_link_species_set object from genomic_align_block");

# 
# 19
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::method_link_species_set method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -method_link_species_set_id => $method_link_species_set_id
      );
  ok($genomic_align->method_link_species_set->dbID, $method_link_species_set_id,
          "Trying to get method_link_species_set object from method_link_species_set_id");

# 
# 20
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::method_link_species_set_id method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -method_link_species_set => $method_link_species_set
      );
  ok($genomic_align->method_link_species_set_id, $method_link_species_set_id,
          "Trying to get method_link_species_set_id from method_link_species_set object");

# 
# 21
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::method_link_species_set_id method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->method_link_species_set_id, $method_link_species_set_id,
          "Trying to get method_link_species_set_id from the database");

# 
# 22
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::dnafrag method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -dnafrag_id => $dnafrag_id,
      );
  ok($genomic_align->dnafrag_id, $dnafrag_id,
          "Trying to get dnafrag object from dnafrag_id");

# 
# 23
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::dnafrag_id method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -dnafrag => $dnafrag,
      );
  ok($genomic_align->dnafrag_id, $dnafrag_id,
          "Trying to get dnafrag_id from dnafrag object");

# 
# 24
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::dnafrag_id method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->dnafrag_id, $dnafrag_id,
          "Trying to get dnafrag_id from the database");

# 
# 25
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::dnafrag_start method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->dnafrag_start, $dnafrag_start,
          "Trying to get dnafrag_start from the database");

# 
# 26
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::dnafrag_end method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->dnafrag_end, $dnafrag_end,
          "Trying to get dnafrag_end from the database");

# 
# 27
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::dnafrag_strand method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->dnafrag_strand, $dnafrag_strand,
          "Trying to get dnafrag_strand from the database");

# 
# 28
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::aligned_sequence method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -original_sequence => $original_sequence,
      -cigar_line => $cigar_line,
      );
  ok($genomic_align->aligned_sequence, $aligned_sequence,
          "Trying to get aligned_sequence from original_sequence and cigar_line");

# 
# 29
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::aligned_sequence method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -cigar_line => $cigar_line,
      );
  ok($genomic_align->aligned_sequence, $aligned_sequence,
          "Trying to get aligned_sequence from original_sequence and cigar_line.\n".
          "- orignal_sequence taken from the database");

# 
# 30
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::aligned_sequence method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -original_sequence => $original_sequence,
      );
  ok($genomic_align->aligned_sequence, $aligned_sequence,
          "Trying to get aligned_sequence from original_sequence and cigar_line.\n".
          "- cigar_line taken from the database");

# 
# 31
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::aligned_sequence method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -original_sequence => $original_sequence,
      );
  ok($genomic_align->aligned_sequence, $aligned_sequence,
          "Trying to get aligned_sequence from original_sequence and cigar_line.\n".
          "- orignal_sequence taken from the database\n".
          "- cigar_line taken from the database");

# 
# 32
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::cigar_line method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -aligned_sequence => $aligned_sequence,
      );
  ok($genomic_align->cigar_line, $cigar_line,
          "Trying to get cigar_line from aligned_sequence");

# 
# 33
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::cigar_line method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->cigar_line, $cigar_line,
          "Trying to get cigar_line from the database");

# 
# 34
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::level_id method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->level_id, $level_id,
          "Trying to get level_id from the database");

# 
# 35
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::original_sequence method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -aligned_sequence => $aligned_sequence
      );
  ok($genomic_align->original_sequence, $original_sequence,
          "Trying to get original_sequence from aligned_sequence");

# 
# 36
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::original_sequence method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->original_sequence, $original_sequence,
          "Trying to get original_sequence from the database");

# 
# 37-38
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::genomic_align_groups method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok(scalar(@{$genomic_align->genomic_align_groups}), scalar(@{$genomic_align_groups}),
          "Trying to get genomic_align_groups from the database");
  do {
    my $all_fails;
    foreach my $this_genomic_align_group (@{$genomic_align->genomic_align_groups}) {
      foreach my $this_genomic_align (@{$this_genomic_align_group->genomic_align_array}) {
        my $fail = $this_genomic_align_group->dbID;
#         my $has_original_GA_been_found = 0;
#         if ($this_genomic_align == $genomic_align_group_1) {
#           $has_original_GA_been_found = 1;
#           ok($this_genomic_align, $genomic_align_1->genomic_align_group_by_type($genomic_align_group->type));
#         }
        foreach my $that_genomic_align_group (@$genomic_align_groups) {
          if ($that_genomic_align_group->dbID == $this_genomic_align_group->dbID) {
            $fail = undef;
            last;
          }
        }
        $all_fails .= " <$fail> " if ($fail);
#         $all_fails .= " Cannot retrieve original GenomicAlign object! " if (!$has_original_GA_been_found);
      }
    }
    ok($all_fails, undef);
  };

# 
# 39-40
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlign::genomic_align_group_by_type method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->genomic_align_group_by_type($genomic_align_group_1_type)->dbID,
          $genomic_align_group_1_id, "Trying to get genomic_align_group_by_type from the database");
  do {
    my $all_fails;
    my $this_genomic_align_group = $genomic_align->genomic_align_group_by_type($genomic_align_group_1_type);
      foreach my $this_genomic_align (@{$this_genomic_align_group->genomic_align_array}) {
      my $fail = $this_genomic_align_group->dbID;
#       my $has_original_GA_been_found = 0;
#       if ($this_genomic_align == $genomic_align_group_1) {
#         $has_original_GA_been_found = 1;
#         ok($this_genomic_align, $genomic_align_1->genomic_align_group_by_type($genomic_align_group->type));
#       }
      foreach my $that_genomic_align_group (@$genomic_align_groups) {
        if ($that_genomic_align_group->dbID == $this_genomic_align_group->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
#       $all_fails .= " Cannot retrieve original GenomicAlign object! " if (!$has_original_GA_been_found);
    }
    ok($all_fails, undef);
  };

exit 0;
