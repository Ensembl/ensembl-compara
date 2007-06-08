#!/usr/bin/perl

use warnings;


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
    plan tests => 196;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
# use Bio::EnsEMBL::Compara::GenomicAlignBlock;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

# verbose('WARNING'); ## Disable API warnings

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
	"pan_troglodytes",
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

our $verbose = 0; ## Set this to 1 to see all the debug(...) messages
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
my $slice_seq_region_name = "16";
my $dnafrag_id = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT dnafrag_id FROM dnafrag df, genome_db gdb
    WHERE df.genome_db_id = gdb.genome_db_id
      AND df.name = \"$slice_seq_region_name\"
      AND df.coord_system_name = \"$slice_coord_system_name\"
      AND gdb.name = \"Homo sapiens\"");
my $slice_start = 72888001;
my $slice_end =   73088000;

$slice_start = 72888001;
$slice_end =   73088000;


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

do {
  debug("coordinates without any excess at the end or start (no cutting any GAB)");

  ($slice_start, $slice_end) = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start, ga1.dnafrag_end
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      AND ga1.genomic_align_id != ga2.genomic_align_id
      AND ga1.method_link_species_set_id = $human_rat_blastznet_mlss->{dbID}
      AND ga1.dnafrag_id = $dnafrag_id
      AND ga2.dnafrag_strand = 1
      AND (ga1.dnafrag_end - ga1.dnafrag_start) > 1600");
  ok($slice_start < $slice_end);
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
  
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]);
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->length,
      $align_slice->get_all_Slices('Rattus norvegicus')->[0]->length);
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);
  $seq = $align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(530, 1600, -1);
  $seq = reverse($seq);
  $seq =~ tr/acgtACGT/tgcaTGCA/;
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(530, 1600), $seq);

  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(),
      join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices()}));
  ok(join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices(undef, 100, -1)}),
      $align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(undef, 100, -1));
  ok(join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices(undef, undef, -1)}),
      $align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(undef, undef, -1));
};

do {
  debug("coordinates with an excess at the end and at the start (cutting GABs)");

  ($slice_start, $slice_end) = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start + 1, ga1.dnafrag_end - 1
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      AND ga1.genomic_align_id != ga2.genomic_align_id
      AND ga1.method_link_species_set_id = $human_rat_blastznet_mlss->{dbID}
      AND ga1.dnafrag_id = $dnafrag_id
      AND ga2.dnafrag_strand = 1
      AND (ga1.dnafrag_end - ga1.dnafrag_start) > 1600");

  ok($slice_start < $slice_end);
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
  
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]);
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->length,
      $align_slice->get_all_Slices('Rattus norvegicus')->[0]->length);
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);

###############################################################################
# GAB restriction is not made in-situ anymore. A copy of the original GAB is
#   used instead
###############################################################################
#   my $all_genomic_align_blocks = $align_slice->get_all_GenomicAlignBlocks();
#   @$all_genomic_align_blocks = sort {$a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start}
#           @$all_genomic_align_blocks;
#   
#   ok($all_genomic_align_blocks->[0]->reference_genomic_align->dnafrag_start, $slice_start,
#       "first GAB should have been truncated");
# 
#   ok($all_genomic_align_blocks->[-1]->reference_genomic_align->dnafrag_end, $slice_end,
#       "last GAB should have been truncated");
###############################################################################

  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(),
      join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices()}));
  ok(join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices(undef, undef, -1)}),
      $align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(undef, undef, -1));
};

do {
  debug("condensed mode: coordinates without any excess at the end or start (no cutting any GAB)");

  ($slice_start, $slice_end) = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start, ga1.dnafrag_end
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      AND ga1.genomic_align_id != ga2.genomic_align_id
      AND ga1.method_link_species_set_id = $human_rat_blastznet_mlss->{dbID}
      AND ga1.dnafrag_id = $dnafrag_id");

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

  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq));
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  ok($seq, $slice->seq);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(),
      join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices()}));
  ok(join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices(undef, undef, -1)}),
      $align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(undef, undef, -1));
};

do {
  debug("coordinates including a piece of mouse in the reverse strand");

  ($slice_start, $slice_end) = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start - 100, ga1.dnafrag_end + 100
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      AND ga1.genomic_align_id != ga2.genomic_align_id
      AND ga1.method_link_species_set_id = $human_rat_blastznet_mlss->{dbID}
      AND ga1.dnafrag_id = $dnafrag_id
      AND ga2.dnafrag_strand = -ga1.dnafrag_strand
      AND (ga1.dnafrag_end - ga1.dnafrag_start) < 1600");

  ok($slice_start < $slice_end);
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

  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]);
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->length,
      $align_slice->get_all_Slices('Rattus norvegicus')->[0]->length);
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss);

  ok($align_slice);

  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq));
  $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  ok($seq, $slice->seq);

  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(),
      join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices()}));
  ok(join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices(undef, undef, -1)}),
      $align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(undef, undef, -1));
};

do {
  debug("coordinates including a piece of mouse in the reverse strand and cutting the GAB");

  ($slice_start, $slice_end) = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start + 1, ga1.dnafrag_end - 1
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      AND ga1.genomic_align_id != ga2.genomic_align_id
      AND ga1.method_link_species_set_id = $human_rat_blastznet_mlss->{dbID}
      AND ga1.dnafrag_id = $dnafrag_id
      AND ga2.dnafrag_strand = -ga1.dnafrag_strand
      AND (ga1.dnafrag_end - ga1.dnafrag_start) < 1600");

  ok($slice_start < $slice_end);
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

  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq));
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss);

  ok($align_slice);

  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq));
  $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  ok($seq, $slice->seq);

  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(),
      join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices()}));
  ok(join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices(undef, undef, -1)}),
      $align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(undef, undef, -1));
};

my $species_name = "Gallus gallus";
my ($excess_start, $excess_end, $exon_id);
my $table_name = $species_db->{"gallus_gallus"}->get_DBAdaptor("core")->dbc->dbname();
my $mlss = $human_chicken_blastznet_mlss;
do {
  debug("coordinates with an excess of X nucleotides surrounding a mapped chicken exon");

  ($slice_start, $slice_end, $excess_start, $excess_end, $exon_id) =
      $compara_db_adaptor->dbc->db_handle->selectrow_array("
        SELECT ga2.dnafrag_start, ga2.dnafrag_end, (seq_region_start - ga1.dnafrag_start),
          (ga1.dnafrag_end - seq_region_end), exon_id
        FROM $table_name.exon LEFT JOIN $table_name.seq_region using (seq_region_id) LEFT JOIN dnafrag using (name)
          LEFT JOIN genome_db using (genome_db_id) LEFT JOIN genomic_align ga1 using (dnafrag_id)
          LEFT JOIN genomic_align ga2 using (genomic_align_block_id)
        WHERE ga2.genomic_align_id != ga1.genomic_align_id
          AND genome_db.name = \"$species_name\"
          AND method_link_species_set_id = $mlss->{dbID}
          AND exon.seq_region_start > ga1.dnafrag_start -5
          AND exon.seq_region_end < ga1.dnafrag_end + 5");

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices($species_name)->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices($species_name)->[0]->seq));
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);
  
  debug("DEBUG slice " . @{$align_slice->get_all_Slices($species_name)}. "  $excess_start  $excess_end");

  my $other_gene = $align_slice->get_all_Slices($species_name)->[0]->get_all_Genes->[0];
  ok($other_gene);
  my $other_transcript = ($other_gene->get_all_Transcripts)->[0];
  ok($other_transcript);
  my $other_exon = (grep {$_->start} @{$other_transcript->get_all_Exons})[0];
  ok($other_exon);
  my $seq1;
  if ($other_exon->strand == 1) {
    $seq1 = $other_exon->seq->seq;
  } else {
    $seq1 = $other_exon->seq->revcom->seq;
  }
  my $seq2 = substr($align_slice->get_all_Slices($species_name)->[0]->seq, $excess_start, -$excess_end);
  ok($seq1, $seq2);

  my $condensed_align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $mlss);
  my $condensed_other_exon = (grep {$_->start} @{$condensed_align_slice->get_all_Slices($species_name)->[0]->get_all_Genes->[0]->get_all_Transcripts->[0]->get_all_Exons})[0];
  my $c_seq1;
  if ($condensed_other_exon->strand == 1) {
    $c_seq1 = $condensed_other_exon->seq->seq;
  } else {
    $c_seq1 = $condensed_other_exon->seq->revcom->seq;
  }
  my $c_seq2 = substr($condensed_align_slice->get_all_Slices($species_name)->[0]->seq, $excess_start, -$excess_end);
  ok($c_seq1, $c_seq2);
  
  $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->subseq($other_exon->start, $other_exon->end);
  $seq2 = "";
  foreach my $subseq ($seq =~ /([ACTG]+|\-+)/g) {
    if ($subseq =~ /\-/) {
      substr($seq1, 0, length($subseq), "");
    } else {
      $seq2 .= substr($seq1, 0, length($subseq), "");
    }
  }
  ok($seq2, $c_seq2);

  ok($align_slice->get_all_Slices($species_name)->[0]->subseq(),
      join("", map {$_->seq} @{$align_slice->get_all_Slices($species_name)->[0]->get_all_underlying_Slices()}));
  ok(join("", map {$_->seq} @{$align_slice->get_all_Slices($species_name)->[0]->get_all_underlying_Slices(undef, undef, -1)}),
      $align_slice->get_all_Slices($species_name)->[0]->subseq(undef, undef, -1));
};

do {
  debug("coordinates matching exactly previous mapped exon");
  $slice_start += $excess_start;
  $slice_end -= $excess_end;

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices($species_name)->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices($species_name)->[0]->seq));
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);

  my $other_gene = $align_slice->get_all_Slices($species_name)->[0]->get_all_Genes->[0];
  ok($other_gene);
  my $other_transcript = ($other_gene->get_all_Transcripts)->[0];
  ok($other_transcript);
  my $other_exon = (grep {$_->start} @{$other_transcript->get_all_Exons})[0];
  ok($other_exon);
  my $seq1;
  if ($other_exon->strand == 1) {
    $seq1 = $other_exon->seq->seq;
  } else {
    $seq1 = $other_exon->seq->revcom->seq;
  }
  my $seq2 = $align_slice->get_all_Slices($species_name)->[0]->seq;
  ok($seq1, $seq2);

  my $condensed_align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $mlss);
  my $condensed_other_exon = (grep {$_->start} @{$condensed_align_slice->get_all_Slices($species_name)->[0]->
      get_all_Genes->[0]->get_all_Transcripts->[0]->get_all_Exons})[0];
  my $c_seq1;
  if ($condensed_other_exon->strand == 1) {
    $c_seq1 = $condensed_other_exon->seq->seq;
  } else {
    $c_seq1 = $condensed_other_exon->seq->revcom->seq;
  }
  my $c_seq2 = $condensed_align_slice->get_all_Slices($species_name)->[0]->seq;
  ok($c_seq1, $c_seq2);
  
  $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->subseq($other_exon->start, $other_exon->end);
  $seq2 = "";
  foreach my $subseq ($seq =~ /([ACTG]+|\-+)/g) {
    if ($subseq =~ /\-/) {
      substr($seq1, 0, length($subseq), "");
    } else {
      $seq2 .= substr($seq1, 0, length($subseq), "");
    }
  }
  ok($seq2, $c_seq2);
};

do {
  debug("test unmapped exons");

  my ($transcript_count) = $compara_db_adaptor->dbc->db_handle->selectrow_array("
      SELECT count(*)
      FROM $table_name.exon_transcript
        LEFT JOIN $table_name.transcript t1 USING (transcript_id)
        LEFT JOIN $table_name.gene using (gene_id)
        LEFT JOIN $table_name.transcript t2 using (gene_id)
      WHERE exon_id = $exon_id");


  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $mlss, "expanded");

  ok($align_slice);

  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices($species_name)->[0]);

  my $other_genes = $align_slice->get_all_Slices->[1]->get_all_Genes();
  ok(@$other_genes, 1, "return 1 single gene");
  ok(@{$other_genes->[0]->get_all_Transcripts}, $transcript_count, "gene contains $transcript_count transcripts");

  my ($exon_count) = $compara_db_adaptor->dbc->db_handle->selectrow_array("
      SELECT count(*)
      FROM $table_name.exon_transcript
      WHERE transcript_id = ".$other_genes->[0]->get_all_Transcripts->[0]->dbID);

  ok(@{$other_genes->[0]->get_all_Transcripts->[0]->get_all_Exons}, $exon_count,
      "transcript 1 contains $exon_count exons");
  my @unmapped_exons = grep {!defined($_->start)}
      @{$other_genes->[0]->get_all_Transcripts->[0]->get_all_Exons};
  ok(@unmapped_exons, ($exon_count - 1), "transcript 1 contains ($exon_count - 1) unmapped exons");

  debug("contains a rat gene with missing exons: skip missing exons");
  my $unmapped_exons = grep {!defined($_->start)}
      @{$other_genes->[0]->get_all_Transcripts->[0]->get_all_Exons};
  my $simple_other_genes = $align_slice->get_all_Slices($species_name)->[0]->get_all_Genes(undef, undef, undef, -RETURN_UNMAPPED_EXONS => 0);
  skip($unmapped_exons == 0,
      @{$simple_other_genes->[0]->get_all_Transcripts->[0]->get_all_Exons} + $unmapped_exons,
      @{$other_genes->[0]->get_all_Transcripts->[0]->get_all_Exons});

};

do {
  debug("slice 1 nucleotide long at the beginning of an non-consecutive alignment.");
  ($slice_start, $slice_end) = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT min(ga1.dnafrag_start), min(ga1.dnafrag_start)
    FROM genomic_align ga1
    WHERE ga1.method_link_species_set_id = $mlss->{dbID}
      AND ga1.dnafrag_id = $dnafrag_id");

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices($species_name)->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices($species_name)->[0]->seq));
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq), 1);
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
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
      $slice, $mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices($species_name)->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices($species_name)->[0]->seq));
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq), 2);
  $seq = $align_slice->get_all_Slices($species_name)->[0]->seq;
  ok($seq, "/^\\.[ACTG]\$/");
};

do {
  debug("slice 1 nucleotide long at the end of an non-consecutive alignment.");

  ($slice_start, $slice_end) = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT max(ga1.dnafrag_end), max(ga1.dnafrag_end)
    FROM genomic_align ga1
    WHERE ga1.method_link_species_set_id = $mlss->{dbID}
      AND ga1.dnafrag_id = $dnafrag_id");

  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices($species_name)->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices($species_name)->[0]->seq));
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq), 1);
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
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
      $slice, $mlss, "expanded");

  ok($align_slice);
  
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices($species_name)->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices($species_name)->[0]->seq));
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq), 2);
  $seq = $align_slice->get_all_Slices($species_name)->[0]->seq;
  ok($seq, "/^[ACTG]\\.\$/");
};

do {
  debug("slice 2 nucleotide long including a gap in human");
  $slice_start = 50220736;
  $slice_end =   50220737;
  my $cigar_line;
  ($slice_start, $slice_end, $cigar_line) = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start, ga1.dnafrag_end, ga1.cigar_line
    FROM genomic_align ga1
    WHERE ga1.method_link_species_set_id = $human_rat_blastznet_mlss->{dbID}
      AND ga1.dnafrag_id = $dnafrag_id
      AND ga1.dnafrag_strand = 1
      AND ga1.cigar_line like \"\%D\%\"");
  my ($skip, $gap_length) = $cigar_line =~ /^(\d*)M(\d*)D/;
  $gap_length ||= 1;
  $slice_start += $skip - 1;
  $slice_end = $slice_start + 1;

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
  
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq));
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq), 2 + $gap_length);
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  $seq =~ s/\-//g;
  ok($seq, $slice->seq);

  my $condensed_align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss);
  ok($condensed_align_slice);
  
  ok($condensed_align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($condensed_align_slice->get_all_Slices('Rattus norvegicus')->[0]);
  ok(length($condensed_align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($condensed_align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq));
  ok(length($condensed_align_slice->get_all_Slices('Homo sapiens')->[0]->seq), 2);
  $seq = $condensed_align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  ok($seq, $slice->seq);
};

do {
  debug("contains an overlapping GenomicAlignBlock");
  $slice_start = 50150000;
  $slice_end =   50190000;
  ($slice_start, $slice_end) = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start - 100, ga2.dnafrag_end + 100
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.method_link_species_set_id = $human_rat_blastznet_mlss->{dbID}
      AND ga2.method_link_species_set_id = $human_rat_blastznet_mlss->{dbID}
      AND ga1.dnafrag_id = $dnafrag_id
      AND ga2.dnafrag_id = $dnafrag_id
      AND ga1.dnafrag_start < ga2.dnafrag_start
      AND ga1.dnafrag_end > ga2.dnafrag_start");
  
  $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  ok($slice);

  my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
          $human_rat_blastznet_mlss, $slice
      );

  # switch off the known warning message
  my $prev_verbose_level = verbose();
  verbose(0);
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss, "expanded");
  verbose($prev_verbose_level);

  ok($align_slice);
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  skip(!defined($slice_start),
    @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_Slice_Mapper_pairs},
    @$genomic_align_blocks - 1);
};

do {
  debug("coordinates without any alignment");

  $slice_start = 50119800;
  $slice_end =   50120295;
  my $all = $compara_db_adaptor->dbc->db_handle->selectall_arrayref("
    SELECT dnafrag_start, dnafrag_end
    FROM genomic_align
    WHERE method_link_species_set_id = $human_rat_blastznet_mlss->{dbID}
      AND dnafrag_id = $dnafrag_id
    ORDER BY dnafrag_start");
  my $last_end;
  foreach my $this_row (@$all) {
    if (defined($last_end)) {
      if ($this_row->[0] - $last_end > 1) {
        $slice_start = $last_end + 1;
        $slice_end = $this_row->[0] - 1;
        last;
      }
    }
    $last_end = $this_row->[1];
  }
  
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
  
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]);
  ok(length($align_slice->get_all_Slices('Homo sapiens')->[0]->seq),
      length($align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq));
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  ok($seq, $slice->seq);
  $seq = $align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq;
  ok($seq, "/^\\.+\$/");

  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->subseq(),
      join("", map {$_->seq} @{$align_slice->get_all_Slices('Rattus norvegicus')->[0]->get_all_underlying_Slices()}));
};

do {
  debug("Test attributes of Bio::EnsEMBL::Compara::AlignSlice::Slice objects...");
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

  debug("... coord_system->name");
  ok($align_slice->reference_Slice->coord_system->name, "chromosome");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system->name, "align_slice");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system->name, "align_slice");

  debug("... coord_system_name");
  ok($align_slice->reference_Slice->coord_system_name, "chromosome");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system_name, "align_slice");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system_name, "align_slice");

  debug("... coord_system->version");
  ok($align_slice->reference_Slice->coord_system->version, '/^NCBI\d+$/');
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system->version,
      "/^chromosome_NCBI\\d+_${slice_seq_region_name}_${slice_start}_${slice_end}_1\\+/");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system->version,
      "/\\+BLASTZ_NET\\(\"Homo sapiens\"\\+\"Rattus norvegicus\"\\)\\+/");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system->version,
      "/\\+expanded/");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system->version,
      "/^chromosome_NCBI\\d+_${slice_seq_region_name}_${slice_start}_${slice_end}_1\\+/");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system->version,
      "/\\+BLASTZ_NET\\(\"Homo sapiens\"\\+\"Rattus norvegicus\"\\)\\+/");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system->version,
      "/\\+expanded/");

  debug("... seq_region_name");
  ok($align_slice->reference_Slice->seq_region_name, $slice_seq_region_name);
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->seq_region_name, "Homo sapiens");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq_region_name, "Rattus norvegicus");

  debug("... seq_region_length");
  my $seq = $align_slice->get_all_Slices('Homo sapiens')->[0]->seq;
  my $gaps = $seq =~ tr/\-/\-/;
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->seq_region_length, ($slice_end-$slice_start+1+$gaps));
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq_region_length, ($slice_end-$slice_start+1+$gaps));

  debug("... start");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->start, 1);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->start, 1);

  debug("... end");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->end, ($slice_end-$slice_start+1+$gaps));
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->end, ($slice_end-$slice_start+1+$gaps));

  debug("... strand");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->strand, 1);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->strand, 1);

  debug("... name");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->name, join(":",
          $align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system_name,
          $align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system->version,
          $align_slice->get_all_Slices('Homo sapiens')->[0]->seq_region_name,
          $align_slice->get_all_Slices('Homo sapiens')->[0]->start,
          $align_slice->get_all_Slices('Homo sapiens')->[0]->end,
          $align_slice->get_all_Slices('Homo sapiens')->[0]->strand)
      );
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->name, join(":",
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system_name,
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system->version,
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq_region_name,
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->start,
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->end,
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->strand)
      );

  
  debug("The same for a \"condensed\" AlignSlice...");
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
      $slice, $human_rat_blastznet_mlss);
  ok($align_slice->reference_Slice->coord_system->name, "chromosome");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system->name, "align_slice");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system->name, "align_slice");

  ok($align_slice->reference_Slice->coord_system_name, "chromosome");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system_name, "align_slice");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system_name, "align_slice");

  ok($align_slice->reference_Slice->coord_system->version, '/^NCBI\d+$/');
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system->version,
      "/^chromosome_NCBI\\d+_${slice_seq_region_name}_${slice_start}_${slice_end}_1\\+/");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system->version,
      "/\\+BLASTZ_NET\\(\"Homo sapiens\"\\+\"Rattus norvegicus\"\\)\\+/");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system->version,
      "/\\+condensed/");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system->version,
      "/^chromosome_NCBI\\d+_${slice_seq_region_name}_${slice_start}_${slice_end}_1\\+/");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system->version,
      "/\\+BLASTZ_NET\\(\"Homo sapiens\"\\+\"Rattus norvegicus\"\\)\\+/");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system->version,
      "/\\+condensed/");

  debug("... seq_region_name");
  ok($align_slice->reference_Slice->seq_region_name, $slice_seq_region_name);
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->seq_region_name, "Homo sapiens");
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq_region_name, "Rattus norvegicus");

  debug("... seq_region_length");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->seq_region_length, ($slice_end-$slice_start+1));
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq_region_length, ($slice_end-$slice_start+1));
  
  debug("... start");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->start, 1);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->start, 1);

  debug("... end");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->end, ($slice_end-$slice_start+1));
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->end, ($slice_end-$slice_start+1));

  debug("... strand");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->strand, 1);
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->strand, 1);

  debug("... name");
  ok($align_slice->get_all_Slices('Homo sapiens')->[0]->name, join(":",
          $align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system_name,
          $align_slice->get_all_Slices('Homo sapiens')->[0]->coord_system->version,
          $align_slice->get_all_Slices('Homo sapiens')->[0]->seq_region_name,
          $align_slice->get_all_Slices('Homo sapiens')->[0]->start,
          $align_slice->get_all_Slices('Homo sapiens')->[0]->end,
          $align_slice->get_all_Slices('Homo sapiens')->[0]->strand)
      );
  ok($align_slice->get_all_Slices('Rattus norvegicus')->[0]->name, join(":",
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system_name,
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->coord_system->version,
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->seq_region_name,
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->start,
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->end,
          $align_slice->get_all_Slices('Rattus norvegicus')->[0]->strand)
      );
};

exit(0);

sub _print_genes {
  my ($all_genes, $align_slice) = @_;

  print STDERR "\n\n";
  foreach my $gene (sort {$a->stable_id cmp $b->stable_id} @$all_genes) {
    print STDERR "GENE: ", $gene->stable_id, " (", $gene->start, "-", $gene->end, ") o[",
        [$align_slice->get_all_Slices->[0]->get_original_seq_region_position($gene->start)]->[1], ",",
        [$align_slice->get_all_Slices->[0]->get_original_seq_region_position($gene->end)]->[1] ,"]o\n";
    foreach my $transcript (sort {($a->stable_id cmp $b->stable_id)
        or ($b->strand <=> $a->strand)
        or ($a->start <=> $b->start)}
            @{$gene->get_all_Transcripts}) {
      print STDERR " + TRANSCRIPT: ", $transcript->stable_id, " (", ($transcript->start or "***"), "-", ($transcript->end or "***"), ") [", $transcript->strand, "]\n";
#       print STDERR " + TRANSLATION: (", ($transcript->cdna_coding_start or "***"), "-", ($transcript->cdna_coding_end or "***"), ")\n";
      foreach my $exon (@{$transcript->get_all_Exons}) {
        if ($exon->isa("Bio::EnsEMBL::Compara::AlignSlice::Exon") and defined($exon->start)) {
          print STDERR "   + EXON: ", $exon->stable_id, " (", $exon->start, "-", $exon->end, ") [",
              $exon->strand, "] -- (", $exon->get_aligned_start, "-", $exon->get_aligned_end, ")  ",
              " -- (", $exon->exon->start, " - ", $exon->exon->end, " ", $exon->exon->strand, ")   -- ",
              ($exon->original_rank or "*"), " ",
              $exon->cigar_line, "\n";
        } elsif ($exon->isa("Bio::EnsEMBL::Compara::AlignSlice::Exon")) {
          print STDERR "   + EXON: ", $exon->stable_id, "    -- ",
              "(", $exon->exon->start, " - ", $exon->exon->end, " ", $exon->exon->strand, ")   -- ",
              $exon->original_rank, "\n";
          next;
        } else {
          print STDERR "   + EXON: ", $exon->stable_id, " (", $exon->start, "-", $exon->end, ") [",
              $exon->strand, "]\n";
          next;
        }
next;
        my $extra = 50;
        my $seq;
        if ($exon->strand == 1) {
          $seq = ("." x $extra).$exon->seq->seq.("." x $extra);
        } else {
          $seq = ("." x $extra).$exon->seq->revcom->seq.("." x $extra);
        }
#         print STDERR substr($align_slice->seq, $exon->start-50, $exon->end+50);
#         my $aseq = $align_slice->subseq($exon->start-50, $exon->end+50);
        my $aseq = $align_slice->get_all_Slices->[1]->subseq($exon->start-$extra, $exon->end+$extra, 1);
        my $bseq = $align_slice->get_all_Slices->[0]->subseq($exon->start-$extra, $exon->end+$extra, 1);
# #         my $cseq = $align_slice->slice->subseq($exon->start-$extra, $exon->end+$extra, 1);
#         $aseq = ("." x 50).$exon->exon->seq->seq.("." x 50);
        $seq =~ s/(.{100})/$1\n/g;
        $seq =~ s/(.{20})/$1 /g;
        $aseq =~ s/(.{100})/$1\n/g;
        $aseq =~ s/(.{20})/$1 /g;
        $bseq =~ s/(.{100})/$1\n/g;
        $bseq =~ s/(.{20})/$1 /g;
# #         $cseq =~ s/(.{100})/$1\n/g;
# #         $cseq =~ s/(.{20})/$1 /g;
        my @seq = split("\n", $seq);
        my @aseq = split("\n", $aseq);
        my @bseq = split("\n", $bseq);
# #         my @cseq = split("\n", $cseq);
        for (my $a=0; $a<@seq; $a++) {
          print STDERR "   ", $seq[$a], "\n";
          print STDERR "   ", $aseq[$a], "\n";
          print STDERR "   ", $bseq[$a], "\n";
# #           print STDERR "   ", $cseq[$a], "\n";
          print STDERR "\n";
        }
      }
    }
  }
}

