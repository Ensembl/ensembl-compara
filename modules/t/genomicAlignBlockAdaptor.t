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
    plan tests => 31;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
# use Bio::EnsEMBL::Compara::GenomicAlignBlock;

# switch off the debug prints 
our $verbose = 0;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");

my $compara_db = $multi->get_DBAdaptor( "compara" );
  
my $genomic_align_adaptor = $compara_db->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_db->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_db->get_MethodLinkSpeciesSetAdaptor();

my $genomic_align_block;
my $all_genomic_align_blocks;
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

my $dnafrag_id = 19;
my $dnafrag_start = 50000000;
my $dnafrag_end = 50001000;
my $all_genomic_align_block_ids = [3639645, 3639663];

# 
# 1-10
# 
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor::fetch_by_dbID method");
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
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor::fetch_all_by_dnafrag_and_method_link_species_set method");
  $all_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_dnafrag_and_method_link_species_set(
      $dnafrag_id, $dnafrag_start, $dnafrag_end, $method_link_species_set_id);
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
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor::retrieve_all_direct_attributes method");
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
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor::store method");
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
debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor::delete method");
  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  ok($genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));
  $genomic_align_block = $genomic_align_block_adaptor->delete_by_dbID($genomic_align_block_id);
  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  ok(!$genomic_align_block);

exit 0;
