#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

genomicAlignBlockAdaptor.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl genomicAlignBlockAdaptor.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor module.

This script includes 31 tests.

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
    plan tests => 32;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
# use Bio::EnsEMBL::Compara::GenomicAlignBlock;

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

my $slice_adaptor = $species_db->{"homo_sapiens"}->get_DBAdaptor("core")->get_SliceAdaptor();
my $genomic_align_adaptor = $compara_db_adaptor->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_db_adaptor->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_db_adaptor->get_MethodLinkSpeciesSetAdaptor();


#####################################################################
##  DATA USED TO TEST API
##

my $genomic_align_block;
my $all_genomic_align_blocks;
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

my $dnafrag_id = 19;
my $dnafrag_start = 50000000;
my $dnafrag_end = 50001000;
##select genomic_align_block_id from genomic_align where dnafrag_id = $dnafrag_id and dnafrag_start <= $dnafrag_end and dnafrag_end >= 50000000;
my $all_genomic_align_block_ids = [5857270, 5857290];

my $slice_coord_system_name = "chromosome";
my $slice_seq_region_name = "14";
my $slice_start = 50000000;
my $slice_end = 50001000;

##
#####################################################################

# 
# 1-10
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->fetch_by_dbID method");
  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  ok($genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));
  ok($genomic_align_block->dbID, $genomic_align_block_id);
  ok($genomic_align_block->adaptor, $genomic_align_block_adaptor);
  ok($genomic_align_block->method_link_species_set_id, $method_link_species_set_id);
  ok($genomic_align_block->method_link_species_set->dbID, $method_link_species_set_id);
  ok($genomic_align_block->score, $score);
  ok($genomic_align_block->perc_id, $perc_id);
  ok($genomic_align_block->length, $length);
  ok(scalar(@{$genomic_align_block->genomic_align_array}), scalar(@$genomic_align_array));
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
        "Trying to get genomic_align_array from the database (returns the unexpected genomic_align_id)");
  };

# 
# 11
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->fetch_all_by_Slice method");
  my $slice = $slice_adaptor->fetch_by_region(
          $slice_coord_system_name,
          $slice_seq_region_name,
          $slice_start,
          $slice_end
      );
  $all_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_Slice(
      $method_link_species_set_id, $slice);
  do {
    my $all_fails;
    foreach my $this_genomic_align_block (@{$all_genomic_align_blocks}) {
      my $fail = $this_genomic_align_block->dbID;
      foreach my $that_genomic_align_block_id (@$all_genomic_align_block_ids) {
        if ($that_genomic_align_block_id == $this_genomic_align_block->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
    }
    ok($all_fails, undef);
  };

# 
# 11
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->fetch_all_by_DnaFrag method");
  $all_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_DnaFrag(
      $method_link_species_set_id, $dnafrag_id, $dnafrag_start, $dnafrag_end);
  do {
    my $all_fails;
    foreach my $this_genomic_align_block (@{$all_genomic_align_blocks}) {
      my $fail = $this_genomic_align_block->dbID;
      foreach my $that_genomic_align_block_id (@$all_genomic_align_block_ids) {
        if ($that_genomic_align_block_id == $this_genomic_align_block->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
    }
    ok($all_fails, undef);
  };

# 
# 12-18
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->retrieve_all_direct_attributes method");
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -dbID => $genomic_align_block_id,
          -adaptor => $genomic_align_block_adaptor
      );
  ok($genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));
  $genomic_align_block_adaptor->retrieve_all_direct_attributes($genomic_align_block);
  ok($genomic_align_block->dbID, $genomic_align_block_id);
  ok($genomic_align_block->adaptor, $genomic_align_block_adaptor);
  ok($genomic_align_block->method_link_species_set_id, $method_link_species_set_id);
  ok($genomic_align_block->score, $score);
  ok($genomic_align_block->perc_id, $perc_id);
  ok($genomic_align_block->length, $length);

# 
# 19
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->store method");
  $genomic_align_1->dbID(0);
  $genomic_align_1->genomic_align_block_id(0);
  $genomic_align_2->dbID(0);
  $genomic_align_2->genomic_align_block_id(0);
  
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -method_link_species_set_id => $method_link_species_set_id,
          -score => $score,
          -length => $length,
          -perc_id => $perc_id,
          -genomic_align_array => $genomic_align_array
      );
  ok($genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));
  $genomic_align_block_adaptor->store($genomic_align_block);
  ok($genomic_align_block->dbID);
  ok($genomic_align_block->dbID != $genomic_align_block_id);
  ok($genomic_align_block->adaptor, $genomic_align_block_adaptor);
  ok($genomic_align_block->method_link_species_set_id, $method_link_species_set_id);
  ok($genomic_align_block->method_link_species_set->dbID, $method_link_species_set_id);
  ok($genomic_align_block->score, $score);
  ok($genomic_align_block->perc_id, $perc_id);
  ok($genomic_align_block->length, $length);
  ok(scalar(@{$genomic_align_block->genomic_align_array}), scalar(@$genomic_align_array));
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
        "Trying to get genomic_align_array from the database (returns the unexpected genomic_align_id)");
  };

$genomic_align_block_id = $genomic_align_block->dbID;
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->delete method");
  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  ok($genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));
  $genomic_align_block = $genomic_align_block_adaptor->delete_by_dbID($genomic_align_block_id);
  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  ok(!$genomic_align_block);

exit 0;
