#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

alignSliceAdaptor.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl alignSliceAdaptor.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script includes 174 tests.

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
    plan tests => 174;
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
foreach my $this_species (reverse sort @$species) {
  $species_db->{$this_species} = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
#   die if (!$species_db->{$this_species});
  
  $species_db_adaptor->{$this_species} = $species_db->{$this_species}->get_DBAdaptor('core');
  
  $species_gdb->{$this_species} = $genome_db_adaptor->fetch_by_name_assembly(
          $species_db_adaptor->{$this_species}->get_MetaContainer->get_Species->binomial,
          $species_db_adaptor->{$this_species}->get_CoordSystemAdaptor->fetch_all->[0]->version
      );
  $species_gdb->{$this_species}->db_adaptor($species_db_adaptor->{$this_species});
}

##
#####################################################################

our $verbose = 0;
my $demo = 0;

my $slice_adaptor = $species_db->{"homo_sapiens"}->get_DBAdaptor("core")->get_SliceAdaptor();
my $align_slice_adaptor = $compara_db_adaptor->get_AlignSliceAdaptor();
my $genomic_align_adaptor = $compara_db_adaptor->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_db_adaptor->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_db_adaptor->get_MethodLinkSpeciesSetAdaptor();
exit if (!$method_link_species_set_adaptor);


#####################################################################
##  DATA USED TO TEST API
##

my $slice_coord_system_name = "chromosome";
my $slice_seq_region_name = "14";
my $slice_start = 50170000;
my $slice_end =   51170000;

$slice_start = 50000000;
$slice_end =   51000000;


#####################################################################
##
## Initialize MethodLinkSpeciesSet objects:
##

my $human_rat_blastznet_mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
        "BLASTZ_NET",
        [$species_gdb->{"homo_sapiens"}, $species_gdb->{"rattus_norvegicus"}]
    );

my $human_chicken_blastznet_mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
        "BLASTZ_NET",
        [$species_gdb->{"homo_sapiens"}, $species_gdb->{"gallus_gallus"}]
    );

##
#####################################################################

my $slice;
my $align_slice;
my $all_genes = [];

$slice_start = 50220031;
$slice_end =   50220682;
do {
  debug("coordinates without any excess at the end or start (no cutting any GAB)");

  $slice_start = 50219800;
  $slice_end =   50221295;
  
  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);
};

do {
  debug("coordinates with an excess at the end and at the start (cutting GABs)");

  $slice_start = 50219820;
  $slice_end =   50221350;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);

  my $all_genomic_align_blocks = $align_slice->get_all_GenomicAlignBlocks();
  @$all_genomic_align_blocks = sort {$a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start}
          @$all_genomic_align_blocks;
  
  ok($all_genomic_align_blocks->[0]->reference_genomic_align->dnafrag_start, $slice_start,
      "first GAB should have been truncated");

  ok($all_genomic_align_blocks->[-1]->reference_genomic_align->dnafrag_end, $slice_end,
      "last GAB should have been truncated");

};

do {
  debug("coordinates with an excess of 5 nucleotides surrounding a mappeed rat exon");

  $slice_start = 50219842;
  $slice_end =   50220747;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);

  my $rat_gene = ($align_slice->get_all_Genes_by_genome_db_id($species_gdb->{'rattus_norvegicus'}->dbID))->[0];
  ok($rat_gene);
  my $rat_transcript = ($rat_gene->get_all_Transcripts)->[0];
  ok($rat_transcript);
  my $rat_exon = ($rat_transcript->get_all_Exons)->[0];
  ok($rat_exon);
  my $seq1;
  if ($rat_exon->strand == 1) {
    $seq1 = $rat_exon->seq->seq;
  } else {
    $seq1 = $rat_exon->seq->revcom->seq;
  }
  my $seq2 = substr($align_slice->{slices}->{'Rattus norvegicus'}->seq, 5, -5);
  ok($seq1, $seq2);
};

do {
  debug("coordinates matching exactly a mapped rat exon");
  $slice_start = 50219847;
  $slice_end =   50220742;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);

  my $rat_gene = ($align_slice->get_all_Genes_by_genome_db_id($species_gdb->{'rattus_norvegicus'}->dbID))->[0];
  ok($rat_gene);
  my $rat_transcript = ($rat_gene->get_all_Transcripts)->[0];
  ok($rat_transcript);
  my $rat_exon = ($rat_transcript->get_all_Exons)->[0];
  ok($rat_exon);
  my $seq1;
  if ($rat_exon->strand == 1) {
    $seq1 = $rat_exon->seq->seq;
  } else {
    $seq1 = $rat_exon->seq->revcom->seq;
  }
  my $seq2 = $align_slice->{slices}->{'Rattus norvegicus'}->seq;
  ok($seq1, $seq2);
};

do {
  debug("slice 1 nucleotide long at the beginnig of the mapped rat exon.");
  $slice_start = 50219811;
  $slice_end =   50219811;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq), 1);
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);

  $slice_start--;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq), 2);
  $seq = $align_slice->{slices}->{'Rattus norvegicus'}->seq;
  ok($seq, "/^\\.[ACTG]\$/");
};

do {
  debug("slice 1 nucleotide long at the end of the mapped rat exon.");
  $slice_start = 50221291;
  $slice_end =   50221291;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq), 1);
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);

  $slice_end++;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq), 2);
  $seq = $align_slice->{slices}->{'Rattus norvegicus'}->seq;
  ok($seq, "/^[ACTG]\\.\$/");
};

do {
  debug("slice 2 nucleotide long including a gap in human");
  $slice_start = 50220736;
  $slice_end =   50220737;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq), 3);
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);
};

do {
  debug("contains a duplicated rat gene on the reverse strand");
  $slice_start = 50213000;
  $slice_end =   50221000;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);
  my $rat_genes = $align_slice->{slices}->{'Rattus norvegicus'}->get_all_Genes;
  ok(@$rat_genes, 1);
  ok(@{$rat_genes->[0]->get_all_Transcripts}, 2);
  ok(($rat_genes->[0]->get_all_Transcripts)->[0]->stable_id,
      ($rat_genes->[0]->get_all_Transcripts)->[1]->stable_id);
};

do {
  debug("contains a piece of duplicated rat gene");
  $slice_start = 50215000;
  $slice_end =   50230000;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);
  my $rat_genes = $align_slice->{slices}->{'Rattus norvegicus'}->get_all_Genes;
  ok(@$rat_genes, 1);
  ok(@{$rat_genes->[0]->get_all_Transcripts}, 2);
  ok(($rat_genes->[0]->get_all_Transcripts)->[0]->stable_id,
      ($rat_genes->[0]->get_all_Transcripts)->[1]->stable_id);
  
  $rat_genes = $align_slice->{slices}->{'Rattus norvegicus'}->get_all_Genes(
          -MAX_INTRON_LENGTH => 10000,
          -MAX_REPETITION_LENGTH => 10000
      );
  ok(@$rat_genes, 1);
  ok(@{$rat_genes->[0]->get_all_Transcripts}, 1);
};

do {
  debug("contains a rat gene with unmapped exons");
  $slice_start = 50172000;
  $slice_end =   50190000;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});

  my $rat_genes = $align_slice->{slices}->{'Rattus norvegicus'}->get_all_Genes();
  ok(@$rat_genes, 1, "return 1 single gene");
  ok(@{$rat_genes->[0]->get_all_Transcripts}, 2, "gene contains 2 transcripts");
  ok(@{$rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons}, 12, "transcript 1 contains 12 exons");
  my @unmapped_genes = grep {!defined($_->start)} @{$rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons};
  ok(@unmapped_genes, 7, "transcript 1 contains 7 unmapped exons");
  ok(@{$rat_genes->[0]->get_all_Transcripts->[1]->get_all_Exons}, 11, "transcript 2 contains 11 exons");
  @unmapped_genes = grep {!defined($_->start)} @{$rat_genes->[0]->get_all_Transcripts->[1]->get_all_Exons};
  ok(@unmapped_genes, 8, "transcript 2 contains 7 unmapped exons");
};

do {
  debug("split transcripts because of intron length");
  $slice_start = 50172000;
  $slice_end =   50190000;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});

  my $rat_genes = $align_slice->{slices}->{'Rattus norvegicus'}->get_all_Genes(-MAX_INTRON_LENGTH => 4000);
  ok(@$rat_genes, 1, "return 1 single gene");
  ok(@{$rat_genes->[0]->get_all_Transcripts}, 4, "gene contains 4 transcripts");
  ok(@{$rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons}, 8, "transcript 1 contains 8 exons");
  ok($rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons->[0]->start, undef,
      "exon 1 of transcript 1 cannot be mapped");
  ok($rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons->[1]->start, undef,
      "exon 2 of transcript 1 cannot be mapped");
  ok($rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons->[2]->start, undef,
      "exon 3 of transcript 1 cannot be mapped");
  ok($rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons->[3]->start, undef,
      "exon 4 of transcript 1 cannot be mapped");
  ok($rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons->[4]->start, undef,
      "exon 5 of transcript 1 cannot be mapped");
  ok($rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons->[5]->start, undef,
      "exon 6 of transcript 1 cannot be mapped");
  ok($rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons->[6]->start, undef,
      "exon 7 of transcript 1 cannot be mapped");
  ok($rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons->[7]->start);
  ok(@{$rat_genes->[0]->get_all_Transcripts->[1]->get_all_Exons}, 4, "transcript 2 contains 8 exons");
  ok(@{$rat_genes->[0]->get_all_Transcripts->[2]->get_all_Exons}, 9, "transcript 9 contains 8 exons");
  ok(@{$rat_genes->[0]->get_all_Transcripts->[3]->get_all_Exons}, 2, "transcript 2 contains 8 exons");
};

do {
  debug("contains a rat gene with missing exons: skip missing exons");
  $slice_start = 50172000;
  $slice_end =   50190000;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});

  my $rat_genes = $align_slice->{slices}->{'Rattus norvegicus'}->get_all_Genes(-RETURN_UNMAPPED_EXONS => 0);
  ok(@$rat_genes, 1, "return 1 single gene");
  ok(@{$rat_genes->[0]->get_all_Transcripts}, 2, "gene contains 2 transcripts");
  ok(@{$rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons}, 5, "transcript 1 contains 5 mapped exons");
  my @unmapped_genes = grep {!defined($_->start)} @{$rat_genes->[0]->get_all_Transcripts->[0]->get_all_Exons};
  ok(@unmapped_genes, 0, "transcript 1 contains no unmapped exons");
  ok(@{$rat_genes->[0]->get_all_Transcripts->[1]->get_all_Exons}, 3, "transcript 2 contains 3 mapped exons");
  @unmapped_genes = grep {!defined($_->start)} @{$rat_genes->[0]->get_all_Transcripts->[1]->get_all_Exons};
  ok(@unmapped_genes, 0, "transcript 2 contains no unmapped exons");
};

do {
  debug("contains a chicken gene with an overlapping GenomicAlignBlock and a unmapped exon in the middle of the gene");
  $slice_start = 50150000;
  $slice_end =   50190000;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
          $human_chicken_blastznet_mlss, $slice
      );
  # switch off the debug prints 
  my $actual_verbosity = verbose();
  verbose(0);
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_chicken_blastznet_mlss, "expanded");
  verbose($actual_verbosity);

  ok($align_slice);
  ok($align_slice->{slices}->{'Homo sapiens'});
  ok(@{$align_slice->{slices}->{'Gallus gallus'}->get_all_Slice_Mapper_pairs}, @$genomic_align_blocks - 1);

  my $chicken_genes = $align_slice->{slices}->{'Gallus gallus'}->get_all_Genes();
  ok(@$chicken_genes, 1, "return 1 single gene");
  ok(@{$chicken_genes->[0]->get_all_Transcripts}, 2, "gene contains 2 transcripts");
  ok(@{$chicken_genes->[0]->get_all_Transcripts->[0]->get_all_Exons}, 14, "transcript 1 contains 14 exons");
  my @unmapped_genes = grep {!defined($_->start)} @{$chicken_genes->[0]->get_all_Transcripts->[0]->get_all_Exons};
  ok(@unmapped_genes, 2, "transcript 1 contains 2 unmapped exons");
  ok($chicken_genes->[0]->get_all_Transcripts->[0]->get_all_Exons->[0]->start, undef,
      "exon 1 of transcript 1 cannot be mapped");
  ok($chicken_genes->[0]->get_all_Transcripts->[0]->get_all_Exons->[7]->start, undef,
      "exon 8 of transcript 1 cannot be mapped");
  ok(@{$chicken_genes->[0]->get_all_Transcripts->[1]->get_all_Exons}, 9, "transcript 2 contains 9 exons");
  @unmapped_genes = grep {!defined($_->start)} @{$chicken_genes->[0]->get_all_Transcripts->[1]->get_all_Exons};
  ok(@unmapped_genes, 2, "transcript 2 contains 2 unmapped exons");
  ok($chicken_genes->[0]->get_all_Transcripts->[1]->get_all_Exons->[0]->start, undef,
      "exon 1 of transcript 2 cannot be mapped");
  ok($chicken_genes->[0]->get_all_Transcripts->[1]->get_all_Exons->[6]->start, undef,
      "exon 7 of transcript 2 cannot be mapped");
};

do {
  debug("condensed mode: coordinates without any excess at the end or start (no cutting any GAB)");

  $slice_start = 50219800;
  $slice_end =   50221295;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss);

  ok($align_slice);

  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  ok($seq, $slice->seq);
ok($align_slice->{slices}->{'Rattus norvegicus'}->seq, "...........TACAAAGGATACAGAATAAATGCAGAGGTCCTGAAATTAGACTGTTTTTCTGAGGAGCCGCCACATGGCGCTCTTGATGTCCCGGTTTCTTAAGCTGTAGATAAAGGGGTTGAGCATAGGGGTGACCACAGTGTACACTATCGATGCTACTGCACCCTTCCTGGGAGACAAGGAGACAGCTGAACTGAGGTATACACCAAGGCCAGTTCCATAAAATAAGCAAACAACTGACAGGTGAGAGCCACAAGTAGAGAAGGCTTTATATTTCCCACCAGGTGATGGCATTCTAAGAATGGAGGAAACAATTTTATAGTAAGAGAAAAAAATCCCTGAAATAGGGAGAAAACCAGAGATGGCACCAACAAAATACATGACTATGTTATTGGTAAAGGTATCAGAACAGGCAAGGTTAAGAAGTTGAGATGGATCACAGAAGAAATGGGAAATGTCCACACTCTTGAAATAGGTAAGTTGTAATACCACTGAATTATGCAGCTGAGAAACCAAAAGGCTTATT-----AGAATAGATAGAAAAACCAACAAGCCACAAAGACGAGGGTTCATAATGACCTGGTAGTGCAGAGGATGGCAGATGGCCACAAACCTATCATAAGCCATGGCTGTTAGAAGCA-GACTA---TCCAAACACCCGAAAAGCATAAAAAAGGACATCTGAGTCAGGCATCCTGAATAGGAAATGGCTCTGTTGTTAGTCTGAATGTCCACTATCATTTTTGGTAGTGTGGTGGAAGTGAAACTTATGTCAGCCAAGGATAAGTTAGAGAGGAAAAAGTACATTGGACTGTGGAGGTGAGAATCAAAGCTGACTGTCAGGATGATGAGCAGGTTCCCAAGAATTGTGACCAAGTACATGAAAAGGAACAGTCCAAAGAGTATGGGCTGAAGCTGTAGATCATCTGAGATCCCATGAGGTGGAATTCTGAGATATGTGTTATATTTTGCTCTTCTATATTGCTTGGACACCTTTTGAAAACAAAAGAAGATTGAAAAAATTAAAACAAGTAA--------CCAATAGTGCCTCTGAGTTTTCAGTGAAGGCAGTTTACTGATAAAATCCACAAATTTAAGGGTTAGGCACAGATATCAGTATTTCTCAGTTTTTACAAACTTA---ATCCTAGAATAATTTTATCATTAATTTTTCTGTTATTTGC--CTCGTTCTACATGTGCACATTAGAGGATTTTAATT----AATCTT---AGGACAAAAGCAACCTAGAAAGGAAGCTTGTGATGATAGTCAAGTAGTGACCATTCTTAAGAGAAAATAGAGAATAACAGAA-------GTTCA-TTTAAGAAAAA---TATTATAGCAAAAGAAAATTAACAAGTCAAAAAATTTATTTTA-------AGAATATTATAAAATT-----AGTTTGAGGATTTGTACATATTGTATAACAATAAGAACTGCTTTGTTTAACAGT-ATATTAAAGTTGA....");
};

do {
  debug("coordinates including a piece of mouse in the reverse strand");

  $slice_start = 50199380;
  $slice_end =   50199510;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);

  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);

  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);
  ok($align_slice->{slices}->{'Rattus norvegicus'}->seq, "..TAATGTTAATTCTAAATAATTCTAGCTTCTATTAAAACTGATAATTAATGTATTAGAAAAATTAC--TGATGCCAATGAGTTCTATATCACTTACCTCAAGAATTTCTTAAAACAATATTAAATTA.......");
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss);

  ok($align_slice);

  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  ok($seq, $slice->seq);
  ok($align_slice->{slices}->{'Rattus norvegicus'}->seq, "..TAATGTTAATTCTAAAATTCTAGCTTCTATTAAAACTGATAATTAATGTATTAGAAAAATTAC--TGATGCCAATGATCTATATCACTTACCTCAAGAATTTCTTAAAACAATATTAAATTA.......");
};

do {
  debug("coordinates including a piece of mouse in the reverse strand and cutting the GAB");

  $slice_start = 50199390;
  $slice_end =   50199500;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);

  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");

  ok($align_slice);

  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  my $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);
  ok($align_slice->{slices}->{'Rattus norvegicus'}->seq, "ATTCTAAATAATTCTAGCTTCTATTAAAACTGATAATTAATGTATTAGAAAAATTAC--TGATGCCAATGAGTTCTATATCACTTACCTCAAGAATTTCTTAAAACAATATTAAA");
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss);

  ok($align_slice);

  ok($align_slice->{slices}->{'Homo sapiens'});
  ok($align_slice->{slices}->{'Rattus norvegicus'});
  ok(length($align_slice->{slices}->{'Homo sapiens'}->seq),
      length($align_slice->{slices}->{'Rattus norvegicus'}->seq));
  $seq = $align_slice->{slices}->{'Homo sapiens'}->seq;
  ok($seq, $slice->seq);
  ok($align_slice->{slices}->{'Rattus norvegicus'}->seq, "ATTCTAAAATTCTAGCTTCTATTAAAACTGATAATTAATGTATTAGAAAAATTAC--TGATGCCAATGATCTATATCACTTACCTCAAGAATTTCTTAAAACAATATTAAA");
};


exit(0);

