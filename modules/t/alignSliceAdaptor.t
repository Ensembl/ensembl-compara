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
    plan tests => 1;
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
my $align_slice_adaptor = $compara_db_adaptor->get_AlignSliceAdaptor();
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
my $dnafrag_start = 50006666;
my $dnafrag_end = 50006788;
##select genomic_align_block_id from genomic_align where dnafrag_id = $dnafrag_id and dnafrag_start <= $dnafrag_end and dnafrag_end >= 50000000;
my $all_genomic_align_block_ids = [5857270, 5857290];

my $slice_coord_system_name = "chromosome";
my $slice_seq_region_name = "14";
my $slice_start = 50200000;
my $slice_end = 50300000;

##
#####################################################################

debug("Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->fetch_all_by_Slice method");
  my $slice = $slice_adaptor->fetch_by_region(
          $slice_coord_system_name,
          $slice_seq_region_name,
          $slice_start,
          $slice_end  
      );
#   $all_genomic_align_blocks = $align_slice_adaptor->fetch_by_Slice_method_link_species_set(
#       $slice, $method_link_species_set_id);
  my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $method_link_species_set_adaptor->fetch_by_dbID(72));
#   my $all_transcripts = $align_slice->get_all_Transcripts();
#   print STDERR "\nTranscript: ", join("\nTranscript: ", map {$_->stable_id} @$all_Transcripts), "\n";
#   my $all_genes = $align_slice->get_all_Genes();
#   print STDERR "\nGene: ", join("\nGene: ", map {$_->stable_id} @$all_Genes), "\n";
#   my $all_exons = $align_slice->get_all_Exons();
#   print STDERR "\nExon: ", join("\nExon: ", map {$_->stable_id} @$all_Exons), "\n";
  
  
#   $all_genes = $align_slice->get_all_Genes($species_gdb->{"homo_sapiens"});
#   print STDERR "\nGene: ", join("\nGene: ", map {$_->stable_id} @$all_Genes), "\n";
#   $all_transcripts = $align_slice->get_all_Transcripts($species_gdb->{"homo_sapiens"});
#   print STDERR "\nTranscript: ", join("\nTranscript: ", map {$_->stable_id} @$all_Transcripts), "\n";
#   $all_exons = $align_slice->get_all_Exons($species_gdb->{"homo_sapiens"});
#   print STDERR "\nExon: ", join("\nExon: ", map {$_->stable_id} @$all_Exons), "\n";

#   $all_genes = $align_slice->get_all_Genes($species_gdb->{"gallus_gallus"});
#   print STDERR "\nGene: ", join("\nGene: ", map {$_->stable_id} @$all_Genes), "\n";
#   $all_transcripts = $align_slice->get_all_Transcripts($species_gdb->{"gallus_gallus"});
#   print STDERR "\nTranscript: ", join("\nTranscript: ", map {$_->stable_id} @$all_Transcripts), "\n";
#   $all_exons = $align_slice->get_all_Exons($species_gdb->{"gallus_gallus"});
#   print STDERR "\nExon: ", join("\nExon: ", map {$_->stable_id} @$all_Exons), "\n";
  
#   print STDERR "\nGene: ", join("\nGene: ", map {$_->slice} @$all_Genes), "\n";
#   print STDERR "\nTranscript: ", join("\nTranscript: ", map {$_->seq->seq} @$all_Transcripts), "\n";
#   print STDERR "\nTranscript: ", join("\nTranscript: ", map {$_->slice} @$all_Transcripts), "\n";
#   print STDERR "\nExon: ", join("\nExon: ", map {$_->seq->seq} @$all_Exons), "\n";
#   print STDERR "\nExon: ", join("\nExon: ", map {$_->slice} @$all_Exons), "\n";
#   print STDERR "\nExon: ", join("\nExon: ", map {$_->start."-".$_->end} @$all_Exons), "\n";

verbose("ALL");
  my $all_genes = $align_slice->get_all_Genes_by_genome_db_id($species_gdb->{"rattus_norvegicus"}->dbID);
  print STDERR "\n\n";
  foreach my $gene (@$all_genes) {
    print STDERR "GENE: ", $gene->stable_id, " (", $gene->start, "-", $gene->end, ")\n";
    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      print STDERR " + TRANSCRIPT: ", $transcript->stable_id, " (", $transcript->start, "-", $transcript->end, ") [", $transcript->strand, "]\n";
      foreach my $exon (@{$transcript->get_all_Exons}) {
        print STDERR "   + EXON: ", $exon->stable_id, " (", $exon->start, "-", $exon->end, ") [", $exon->strand, "] -- ",
            $exon->cigar_line, "\n";
          
        my $seq;
        if ($exon->strand == 1) {
          $seq = ("." x 50).$exon->seq->seq.("." x 50);
        } else {
          $seq = ("." x 50).$exon->seq->revcom->seq.("." x 50);
        }
        my $aseq = $align_slice->reference_Slice->subseq($exon->start-50, $exon->end+50);
        $seq =~ s/(.{80})/$1\n/g;
        $aseq =~ s/(.{80})/$1\n/g;
        $seq =~ s/(.{20})/$1 /g;
        $aseq =~ s/(.{20})/$1 /g;
        my @seq = split("\n", $seq);
        my @aseq = split("\n", $aseq);
        for (my $a=0; $a<@seq; $a++) {
          print STDERR "   ", $seq[$a], "\n";
          print STDERR "   ", $aseq[$a], "\n";
          print STDERR "\n";
        }
      }
    }
  }
  
  ok(1);
