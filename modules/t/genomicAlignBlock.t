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

This script includes 27 tests.

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
    plan tests => 26;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;

# switch off the debug prints 
our $verbose = 0;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");

my $compara_db = $multi->get_DBAdaptor( "compara" );
my $gdba = $compara_db->get_GenomeDBAdaptor();

my $hs_gdb = $gdba->fetch_by_name_assembly( "Homo sapiens", 'NCBI34' );
my $mm_gdb = $gdba->fetch_by_name_assembly( "Mus musculus", 'NCBIM32' );
my $rn_gdb = $gdba->fetch_by_name_assembly( "Rattus norvegicus", 'RGSC3.1' );

$hs_gdb->db_adaptor($homo_sapiens->get_DBAdaptor('core'));
$mm_gdb->db_adaptor($mus_musculus->get_DBAdaptor('core'));
$rn_gdb->db_adaptor($rattus_norvegicus->get_DBAdaptor('core'));
  
# my $genomic_align;
# my $all_genomic_aligns;
my $genomic_align_adaptor = $compara_db->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_db->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_db->get_MethodLinkSpeciesSetAdaptor();
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

my $genomic_align_block;
my $genomic_align_block_id = 3639804;
my $method_link_species_set_id = 2;
my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
my $score = 4491;
my $perc_id = 63;
my $length = 158;
my $genomic_algin_1_dbID = 7279606;
my $genomic_align_1 = $genomic_align_adaptor->fetch_by_dbID($genomic_algin_1_dbID);
my $genomic_algin_2_dbID = 7279608;
my $genomic_align_2 = $genomic_align_adaptor->fetch_by_dbID($genomic_algin_2_dbID);
my $genomic_align_array = [$genomic_align_1, $genomic_align_2];

# 
# 1
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::new(void) method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  ok($genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));

# 
# 2-9
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::new(ALL) method");
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
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::adaptor method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->adaptor($genomic_align_block_adaptor);
  ok($genomic_align_block->adaptor, $genomic_align_block_adaptor);

# 
# 10
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::dbID method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->dbID($genomic_align_block_id);
  ok($genomic_align_block->dbID, $genomic_align_block_id);

# 
# 11
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::method_link_species_set method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->method_link_species_set($method_link_species_set);
  ok($genomic_align_block->method_link_species_set, $method_link_species_set);

# 
# 12
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::method_link_species_set method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -method_link_species_set_id => $method_link_species_set_id,
      );
  ok($genomic_align_block->method_link_species_set->dbID, $method_link_species_set_id,
      "Trying to get method_link_species_set object from method_link_species_set_id");

# 
# 13
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::method_link_species_set_id method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->method_link_species_set_id($method_link_species_set_id);
  ok($genomic_align_block->method_link_species_set_id, $method_link_species_set_id);

# 
# 14
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::method_link_species_set_id method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->method_link_species_set_id($method_link_species_set_id);
  ok($genomic_align_block->method_link_species_set_id, $method_link_species_set_id);

# 
# 15
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::method_link_species_set_id method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -method_link_species_set => $method_link_species_set,
      );
  ok($genomic_align_block->method_link_species_set_id, $method_link_species_set_id,
      "Trying to get method_link_species_set_id from method_link_species_set object");

# 
# 16
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::method_link_species_set_id method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  ok($genomic_align_block->method_link_species_set_id, $method_link_species_set_id,
      "Trying to get method_link_species_set_id from the database");

# 
# 17
# 
foreach my $this_genomic_align (@$genomic_align_array) {
  $this_genomic_align->genomic_align_block_id(0);
}
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::genomic_align_array method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->genomic_align_array($genomic_align_array);
  ok($genomic_align_block->genomic_align_array, $genomic_align_array);

# 
# 18-19
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::genomic_align_array method");
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

# 
# 20
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::score method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->score($score);
  ok($genomic_align_block->score, $score);

# 
# 21
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::score method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  ok($genomic_align_block->score, $score,
      "Trying to get score from the database");

# 
# 22
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::perc_id method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->perc_id($perc_id);
  ok($genomic_align_block->perc_id, $perc_id);

# 
# 23
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::score method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  ok($genomic_align_block->perc_id, $perc_id,
      "Trying to get perc_id from the database");

# 
# 24
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::lenght method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
  $genomic_align_block->length($length);
  ok($genomic_align_block->length, $length);

# 
# 25
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::score method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -dbID => $genomic_align_block_id,
      );
  ok($genomic_align_block->length, $length,
      "Trying to get length from the database");

# 
# 26
# 
debug("Test Bio::EnsEMBL::Compara::GenomicAlignBlock::lenght method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -dbID => $genomic_align_block_id,
          -adaptor => $genomic_align_block_adaptor
      );
  ok(scalar(@{$genomic_align_block->alignment_strings}), scalar(@{$genomic_align_array}));



exit 0;
