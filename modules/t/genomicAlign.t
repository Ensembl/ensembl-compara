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

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl genomicAlign.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::GenomicAlign module.

This script includes 91 tests.

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
    plan tests => 45;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

# switch off the debug prints 
our $verbose = 0;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

verbose("EXCEPTION");

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

my $species = [
        "homo_sapiens",
        "mus_musculus",
        "rattus_norvegicus",
        "gallus_gallus",
	"bos_taurus",
	"canis_familiaris",
	"macaca_mulatta",
	"monodelphis_domestica",
	"ornithorhynchus_anatinus",
	"pan_troglodytes"
    ];

## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (@$species) {
  my $species_db = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  my $species_db_adaptor = $species_db->get_DBAdaptor('core');
  my $species_gdb = $genome_db_adaptor->fetch_by_name_assembly(
          $species_db_adaptor->get_MetaContainer->get_Species->binomial,
          $species_db_adaptor->get_CoordSystemAdaptor->fetch_all->[0]->version
      );
  $species_gdb->db_adaptor($species_db_adaptor);
}

##
#####################################################################
  
my $genomic_align;
my $all_genomic_aligns;
my $genomic_align_adaptor = $compara_db_adaptor->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_db_adaptor->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_db_adaptor->get_MethodLinkSpeciesSetAdaptor();
my $dnafrag_adaptor = $compara_db_adaptor->get_DnaFragAdaptor();
my $genomic_align_group_adaptor = $compara_db_adaptor->get_GenomicAlignGroupAdaptor();
my $genomeDB_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();
my $fail;

my $sth;
$sth = $compara_db_adaptor->dbc->prepare("SELECT
      genomic_align_id, genomic_align_block_id, method_link_species_set_id, dnafrag_id,
      dnafrag_start, dnafrag_end, dnafrag_strand, cigar_line, level_id
    FROM genomic_align WHERE level_id = 1 and dnafrag_strand = 1 AND cigar_line like \"\%D\%\" LIMIT 1");
$sth->execute();
my ($dbID, $genomic_align_block_id, $method_link_species_set_id, $dnafrag_id,
    $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line, $level_id) =
    $sth->fetchrow_array();
$sth->finish();

$sth = $compara_db_adaptor->dbc->prepare("SELECT
      group_id, type
    FROM genomic_align_group WHERE genomic_align_id = $dbID LIMIT 1");
$sth->execute();
my ($genomic_align_group_1_id, $genomic_align_group_1_type) =
    $sth->fetchrow_array();
$sth->finish();

my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
my $method_link_species_set =
    $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
my $genomic_align_group_1 =
    $genomic_align_group_adaptor->fetch_by_dbID($genomic_align_group_1_id);
my $genomic_align_groups =[];
if (defined $genomic_align_group_1) {
    $genomic_align_groups = [$genomic_align_group_1];
}

my $aligned_sequence = "AAGGTCCCTAGTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCT-AACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGGCAAGTTCAAGGCCACTGCTTCCACTAGCAGAGAGGTGGTTGAGGTTCCTCCCAGTCACCACAGAGAAGATTTAACAAGTAAAAACCTGCAAACTCTTTATTAAATTCTCCCATTTCATCTGTACAGAAAAAAATGCACATTATGTTCAGAACATATCTCAGTAACATCTCAAAATTACACAGCATGAACATGTAAAAACAAGGGACCACCACGATTTTATACATAGAAAGGAAACCCATTTACAAAAGAGGCTTGTTAATTGTATTTTTTTCTTTCTTTCAAAAACAAAA---CAAAACAAAAA-AAGTGAAAAGCCTAAGATCTCACACAGCATTTGCTGTACAGACTGTTTTCCGGATGGACTGGTTTGGGAACACTGTGCTGGGGGAAGCTGCCCAGGAAGCGCTCCCGCTGC---CGGCTTTCCGGAGGTCTCTGCCCAGTGCACTGCAGGGGGACCTGGAGGGCCCATTTCTACCACCCTAGCATGTCTGACAGAAAGCCCTGCTGGGCTCTGGGGTCCAGATGTCAACTCTACATTGGAGGAGGCAAAACACAATCTAGAGGCA----CTGTCTGAACTTTCCCCTGGCCCAGGGAGATTTCTCCACTGCACACAGCACAGTGTCCTATACATGTGTCCTGGTGGAGCAGAGGGA-GCGGGAGAGGACC---ACGGGTCAGGATCCTGTCACCACCAGCCTGAGCAGACAGTCCCATCTTTGTGATCCAGGTGACAAATAATCAGTCCCTG-GTCCCCACAATGACCTCACCAGATGGCTTTGGGGAGCTCTTCACCCTAAAGATTCGGTCTGGTTTGCTAATGACTTATCTATTATCTGAAGTCTGTGGAGGAAG";

my $original_sequence = "AAGGTCCCTAGTCCTCTAAAAGTCCTTGAGTCCTACTCTGCTGAACCTAACTGGTCAAGAACTAAGGACCTGATCAGCAAGGTTTGTGAGCATCAGTTGGCAAGTTCAAGGCCACTGCTTCCACTAGCAGAGAGGTGGTTGAGGTTCCTCCCAGTCACCACAGAGAAGATTTAACAAGTAAAAACCTGCAAACTCTTTATTAAATTCTCCCATTTCATCTGTACAGAAAAAAATGCACATTATGTTCAGAACATATCTCAGTAACATCTCAAAATTACACAGCATGAACATGTAAAAACAAGGGACCACCACGATTTTATACATAGAAAGGAAACCCATTTACAAAAGAGGCTTGTTAATTGTATTTTTTTCTTTCTTTCAAAAACAAAACAAAACAAAAAAAGTGAAAAGCCTAAGATCTCACACAGCATTTGCTGTACAGACTGTTTTCCGGATGGACTGGTTTGGGAACACTGTGCTGGGGGAAGCTGCCCAGGAAGCGCTCCCGCTGCCGGCTTTCCGGAGGTCTCTGCCCAGTGCACTGCAGGGGGACCTGGAGGGCCCATTTCTACCACCCTAGCATGTCTGACAGAAAGCCCTGCTGGGCTCTGGGGTCCAGATGTCAACTCTACATTGGAGGAGGCAAAACACAATCTAGAGGCACTGTCTGAACTTTCCCCTGGCCCAGGGAGATTTCTCCACTGCACACAGCACAGTGTCCTATACATGTGTCCTGGTGGAGCAGAGGGAGCGGGAGAGGACCACGGGTCAGGATCCTGTCACCACCAGCCTGAGCAGACAGTCCCATCTTTGTGATCCAGGTGACAAATAATCAGTCCCTGGTCCCCACAATGACCTCACCAGATGGCTTTGGGGAGCTCTTCACCCTAAAGATTCGGTCTGGTTTGCTAATGACTTATCTATTATCTGAAGTCTGTGGAGGAAG";


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
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -genomic_align_block_id => $genomic_align_block_id + 1
      );
  ok(eval{$genomic_align->genomic_align_block($genomic_align_block)}, undef,
          "Testing throw condition");

# 
# 17
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
# 18
# 
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->genomic_align_block_id, $genomic_align_block_id,
          "Trying to get object genomic_align_block_id from the database");

# 
# 19
# 
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -genomic_align_block => $genomic_align_block
      );
  ok(eval{$genomic_align->genomic_align_block_id($genomic_align_block_id + 1)}, undef,
          "Testing throw condition");

# 
# 20
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
# 21
# 
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -method_link_species_set_id => $method_link_species_set_id
      );
  ok($genomic_align->method_link_species_set->dbID, $method_link_species_set_id,
          "Trying to get method_link_species_set object from method_link_species_set_id");

# 
# 22
# 
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->method_link_species_set->dbID, $method_link_species_set_id,
          "Trying to get method_link_species_set object from the database");


# 
# 23
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
# 24
#
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->method_link_species_set_id, $method_link_species_set_id,
          "Trying to get method_link_species_set_id from the database");


# 
# 25
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
# 26
# 
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -dnafrag_id => $dnafrag_id + 1
      );
  ok(eval{$genomic_align->dnafrag($dnafrag)}, undef,
          "Testing throw condition");

debug("Test Bio::EnsEMBL::Compara::GenomicAlign::dnafrag_id method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -dnafrag => $dnafrag,
      );
  ok($genomic_align->dnafrag_id, $dnafrag_id,
          "Trying to get dnafrag_id from dnafrag object");


  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->dnafrag_id, $dnafrag_id,
          "Trying to get dnafrag_id from the database");


  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -dnafrag => $dnafrag,
      );
  ok(eval{$genomic_align->dnafrag_id($dnafrag_id + 1)}, undef,
          "Testing throw condition");


debug("Test Bio::EnsEMBL::Compara::GenomicAlign::dnafrag_start method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->dnafrag_start, $dnafrag_start,
          "Trying to get dnafrag_start from the database");


debug("Test Bio::EnsEMBL::Compara::GenomicAlign::dnafrag_end method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->dnafrag_end, $dnafrag_end,
          "Trying to get dnafrag_end from the database");


debug("Test Bio::EnsEMBL::Compara::GenomicAlign::dnafrag_strand method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->dnafrag_strand, $dnafrag_strand,
          "Trying to get dnafrag_strand from the database");


debug("Test Bio::EnsEMBL::Compara::GenomicAlign::aligned_sequence method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -original_sequence => $original_sequence,
      -cigar_line => $cigar_line,
      );

  ok($genomic_align->aligned_sequence, $aligned_sequence,
          "Trying to get aligned_sequence from original_sequence and cigar_line");


debug("Test Bio::EnsEMBL::Compara::GenomicAlign::aligned_sequence method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -cigar_line => $cigar_line,
      );
  ok($genomic_align->aligned_sequence, $aligned_sequence,
          "Trying to get aligned_sequence from original_sequence and cigar_line.\n".
          "- orignal_sequence taken from the database");

  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -original_sequence => $original_sequence,
      );
  ok($genomic_align->aligned_sequence, $aligned_sequence,
          "Trying to get aligned_sequence from original_sequence and cigar_line.\n".
          "- cigar_line taken from the database");

  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -original_sequence => $original_sequence,
      );
  ok($genomic_align->aligned_sequence, $aligned_sequence,
          "Trying to get aligned_sequence from original_sequence and cigar_line.\n".
          "- orignal_sequence taken from the database\n".
          "- cigar_line taken from the database");


debug("Test Bio::EnsEMBL::Compara::GenomicAlign::cigar_line method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      -aligned_sequence => $aligned_sequence,
      );
  ok($genomic_align->cigar_line, $cigar_line,
          "Trying to get cigar_line from aligned_sequence");

  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->cigar_line, $cigar_line,
          "Trying to get cigar_line from the database");


debug("Test Bio::EnsEMBL::Compara::GenomicAlign::level_id method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->level_id, $level_id,
          "Trying to get level_id from the database");


debug("Test Bio::EnsEMBL::Compara::GenomicAlign::original_sequence method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -dbID => $dbID,
      -aligned_sequence => $aligned_sequence,
      -dnafrag_strand => 1
      );
  ok($genomic_align->original_sequence, $original_sequence,
          "Trying to get original_sequence from aligned_sequence");


debug("Test Bio::EnsEMBL::Compara::GenomicAlign::original_sequence method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );
  ok($genomic_align->original_sequence, $original_sequence,
          "Trying to get original_sequence from the database");


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


debug("Test Bio::EnsEMBL::Compara::GenomicAlign::genomic_align_group_by_type method");
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -dbID => $dbID,
      );

#can only do these tests if the genomic_align_group table contains $genomic_align_group_1_type
if (defined $genomic_align_group_1_type) {
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
    }
};
    


exit 0;
