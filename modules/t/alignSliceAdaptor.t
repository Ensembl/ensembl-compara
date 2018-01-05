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

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

my $ref_species = "homo_sapiens";
my $species = [
        "homo_sapiens",
        "mus_musculus",
        "pan_troglodytes",
    ];

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_dba = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();

my $species_db;
my $species_gdb;

## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (reverse sort @$species) {
  $species_db->{$this_species} = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  die if (!$species_db->{$this_species});
}

##
#####################################################################

my $slice_adaptor = $species_db->{"homo_sapiens"}->get_DBAdaptor("core")->get_SliceAdaptor();
my $align_slice_adaptor = $compara_dba->get_AlignSliceAdaptor();
my $genomic_align_adaptor = $compara_dba->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
exit if (!$method_link_species_set_adaptor);


#####################################################################
##  DATA USED TO TEST API
##

my $slice_coord_system_name = "chromosome";
my $slice_seq_region_name = "6";
my $dnafrag_id = $compara_dba->dbc->db_handle->selectrow_array("
    SELECT dnafrag_id FROM dnafrag df, genome_db gdb
    WHERE df.genome_db_id = gdb.genome_db_id
      AND df.name = \"$slice_seq_region_name\"
      AND df.coord_system_name = \"$slice_coord_system_name\"
      AND gdb.name = \"$ref_species\"");
my $this_slice_start = 31500000;
my $this_slice_end = 32000000;


#####################################################################
##
## Initialize MethodLinkSpeciesSet objects:
##

my $human_mouse_lastznet_mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_registry_aliases(
        "LASTZ_NET",
        [ "homo_sapiens", "mus_musculus" ]
    );

my $human_chimp_lastznet_mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_registry_aliases(
        "LASTZ_NET",
        [ "homo_sapiens", "pan_troglodytes" ]
    );

##
#####################################################################

my $slice;
my $align_slice;
my $all_genes = [];

#
#coordinates without any excess at the end or start (no cutting any GAB)
#
subtest "Test coordinates without any excess at the end or start", sub {
    my $ref_species = "homo_sapiens";
    my $non_ref_species = "pan_troglodytes";
    my $mlss = $human_chimp_lastznet_mlss;
    my $mlss_id = $mlss->{dbID};
    
  my ($slice_start, $slice_end) = $compara_dba->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start, ga1.dnafrag_end
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      AND ga1.genomic_align_id != ga2.genomic_align_id
      AND ga1.method_link_species_set_id = $mlss_id 
      AND ga1.dnafrag_id = $dnafrag_id 
      AND ga2.dnafrag_strand = 1 
      AND (ga1.dnafrag_end - ga1.dnafrag_start) > 1600 ORDER BY ga1.dnafrag_start LIMIT 1");

  ok($slice_start < $slice_end, "start is less than end");
  $slice = $slice_adaptor->fetch_by_region(
                                           $slice_coord_system_name,
                                           $slice_seq_region_name,
                                           $slice_start,
                                           $slice_end,
                                           1
                                          );
  isa_ok($slice, "Bio::EnsEMBL::Slice", "check object");
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
                                                                           $slice, $mlss, "expanded");

  isa_ok($align_slice,"Bio::EnsEMBL::Compara::AlignSlice", "check object");

  is($align_slice->get_all_Slices($ref_species)->[0]->length,
     $align_slice->get_all_Slices($non_ref_species)->[0]->length, "slice length");

    my $seq = $align_slice->get_all_Slices($ref_species)->[0]->seq;
    $seq =~ s/\-//g;
    is($seq, $slice->seq, "seq");

    $seq = $align_slice->get_all_Slices($non_ref_species)->[0]->subseq(530, 1600, -1);
    $seq = reverse($seq);
    $seq =~ tr/acgtACGT/tgcaTGCA/;
    is($align_slice->get_all_Slices($non_ref_species)->[0]->subseq(530, 1600), $seq, "reverse seq");

    is($align_slice->get_all_Slices($non_ref_species)->[0]->subseq(),
       join("", map {$_->seq} @{$align_slice->get_all_Slices($non_ref_species)->[0]->get_all_underlying_Slices()}), "underlying slices");
    is(join("", map {$_->seq} @{$align_slice->get_all_Slices($non_ref_species)->[0]->get_all_underlying_Slices(undef, 100, -1)}),
       $align_slice->get_all_Slices($non_ref_species)->[0]->subseq(undef, 100, -1), "underlying slices");
    is(join("", map {$_->seq} @{$align_slice->get_all_Slices($non_ref_species)->[0]->get_all_underlying_Slices(undef, undef, -1)}),
       $align_slice->get_all_Slices($non_ref_species)->[0]->subseq(undef, undef, -1), "underlying slices");

  done_testing();
};

subtest "Test coordinates with an excess at the end and at the start (cutting GABs)", sub {
    my $ref_species = "homo_sapiens";
    my $non_ref_species = "pan_troglodytes";
    my $mlss = $human_chimp_lastznet_mlss;
    my $mlss_id = $mlss->{dbID};

  my ($slice_start, $slice_end) = $compara_dba->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start + 1, ga1.dnafrag_end - 1
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      AND ga1.genomic_align_id != ga2.genomic_align_id
      AND ga1.method_link_species_set_id = $mlss_id
      AND ga1.dnafrag_id = $dnafrag_id
      AND ga2.dnafrag_strand = 1
      AND (ga1.dnafrag_end - ga1.dnafrag_start) > 1600 ORDER BY ga1.dnafrag_start LIMIT 1");

  ok($slice_start < $slice_end, "start is less than end");
    $slice = $slice_adaptor->fetch_by_region(
        $slice_coord_system_name,
        $slice_seq_region_name,
        $slice_start,
        $slice_end,
        1
    );
  isa_ok($slice, "Bio::EnsEMBL::Slice", "check object");
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $mlss, "expanded");

  isa_ok($align_slice,"Bio::EnsEMBL::Compara::AlignSlice", "check object");

  is($align_slice->get_all_Slices($ref_species)->[0]->length,
     $align_slice->get_all_Slices($non_ref_species)->[0]->length, "slice length");

    my $seq = $align_slice->get_all_Slices($ref_species)->[0]->seq;
    $seq =~ s/\-//g;
    is($seq, $slice->seq, "seq");

    is($align_slice->get_all_Slices($non_ref_species)->[0]->subseq(),
      join("", map {$_->seq} @{$align_slice->get_all_Slices($non_ref_species)->[0]->get_all_underlying_Slices()}), "underlying slices");
    is(join("", map {$_->seq} @{$align_slice->get_all_Slices($non_ref_species)->[0]->get_all_underlying_Slices(undef, undef, -1)}),
      $align_slice->get_all_Slices($non_ref_species)->[0]->subseq(undef, undef, -1), "underlying slices");

    done_testing();
};

subtest "Test condensed mode: coordinates without any excess at the end or start (no cutting any GAB)", sub {
    my $ref_species = "homo_sapiens";
    my $non_ref_species = "pan_troglodytes";
    my $mlss = $human_chimp_lastznet_mlss;
    my $mlss_id = $mlss->{dbID};
    
  my ($slice_start, $slice_end) = $compara_dba->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start, ga1.dnafrag_end
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      AND ga1.genomic_align_id != ga2.genomic_align_id
      AND ga1.method_link_species_set_id = $mlss_id
      AND ga1.dnafrag_id = $dnafrag_id");

  $slice = $slice_adaptor->fetch_by_region(
                                           $slice_coord_system_name,
                                           $slice_seq_region_name,
                                           $slice_start,
                                           $slice_end,
                                           1
                                          );
  isa_ok($slice, "Bio::EnsEMBL::Slice", "check object");
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $mlss);
  isa_ok($align_slice,"Bio::EnsEMBL::Compara::AlignSlice", "check object");
  is($align_slice->get_all_Slices($ref_species)->[0]->length,
     $align_slice->get_all_Slices($non_ref_species)->[0]->length, "slice length");

    my $seq = $align_slice->get_all_Slices($ref_species)->[0]->seq;
    is($seq, $slice->seq, "seq");

    is($align_slice->get_all_Slices($non_ref_species)->[0]->subseq(),
      join("", map {$_->seq} @{$align_slice->get_all_Slices($non_ref_species)->[0]->get_all_underlying_Slices()}), "underlying slices");
    is(join("", map {$_->seq} @{$align_slice->get_all_Slices($non_ref_species)->[0]->get_all_underlying_Slices(undef, undef, -1)}),
      $align_slice->get_all_Slices($non_ref_species)->[0]->subseq(undef, undef, -1), "underlying slices");

    done_testing();
};

subtest "Test coordinates including a piece of mouse in the reverse strand", sub {
    my $ref_species = "homo_sapiens";
    my $non_ref_species = "mus_musculus";
    my $mlss = $human_mouse_lastznet_mlss;
    my $mlss_id = $mlss->{dbID};

    my ($slice_start, $slice_end) = $compara_dba->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start - 100, ga1.dnafrag_end + 100
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      AND ga1.genomic_align_id != ga2.genomic_align_id
      AND ga1.method_link_species_set_id = $mlss_id
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
  isa_ok($slice, "Bio::EnsEMBL::Slice", "check object");
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $mlss, "expanded");

  isa_ok($align_slice,"Bio::EnsEMBL::Compara::AlignSlice", "check object");
  is($align_slice->get_all_Slices($ref_species)->[0]->length,
     $align_slice->get_all_Slices($non_ref_species)->[0]->length, "slice length");

    my $seq = $align_slice->get_all_Slices($ref_species)->[0]->seq;
    $seq =~ s/\-//g;
    is($seq, $slice->seq, "seq");

    #non-expanded
    $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $mlss);

    isa_ok($align_slice,"Bio::EnsEMBL::Compara::AlignSlice", "check object");
    is($align_slice->get_all_Slices($ref_species)->[0]->length,
       $align_slice->get_all_Slices($non_ref_species)->[0]->length, "slice length");
    
    $seq = $align_slice->get_all_Slices($ref_species)->[0]->seq;
    is($seq, $slice->seq, "seq");

    is($align_slice->get_all_Slices($non_ref_species)->[0]->subseq(),
      join("", map {$_->seq} @{$align_slice->get_all_Slices($non_ref_species)->[0]->get_all_underlying_Slices()}), "underlying slices");
    is(join("", map {$_->seq} @{$align_slice->get_all_Slices($non_ref_species)->[0]->get_all_underlying_Slices(undef, undef, -1)}),
      $align_slice->get_all_Slices($non_ref_species)->[0]->subseq(undef, undef, -1), "underlying slices");

    done_testing();
};

subtest "Test coordinates including a piece of mouse in the reverse strand and cutting the GAB", sub {
        my $ref_species = "homo_sapiens";
    my $non_ref_species = "mus_musculus";
    my $mlss = $human_mouse_lastznet_mlss;
    my $mlss_id = $mlss->{dbID};

    my ($slice_start, $slice_end) = $compara_dba->dbc->db_handle->selectrow_array("
    SELECT ga1.dnafrag_start + 1, ga1.dnafrag_end - 1
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      AND ga1.genomic_align_id != ga2.genomic_align_id
      AND ga1.method_link_species_set_id = $mlss_id
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
  isa_ok($slice, "Bio::EnsEMBL::Slice", "check object");
  
  $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $mlss, "expanded");

  isa_ok($align_slice,"Bio::EnsEMBL::Compara::AlignSlice", "check object");
  is($align_slice->get_all_Slices($ref_species)->[0]->length,
     $align_slice->get_all_Slices($non_ref_species)->[0]->length, "slice length");

    my $seq = $align_slice->get_all_Slices($ref_species)->[0]->seq;
    $seq =~ s/\-//g;
    is($seq, $slice->seq, "seq");

    #non-expanded
    $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $mlss);

    isa_ok($align_slice,"Bio::EnsEMBL::Compara::AlignSlice", "check object");
    is($align_slice->get_all_Slices($ref_species)->[0]->length,
       $align_slice->get_all_Slices($non_ref_species)->[0]->length, "slice length");
    
    $seq = $align_slice->get_all_Slices($ref_species)->[0]->seq;
    is($seq, $slice->seq, "seq");

    is($align_slice->get_all_Slices($non_ref_species)->[0]->subseq(),
      join("", map {$_->seq} @{$align_slice->get_all_Slices($non_ref_species)->[0]->get_all_underlying_Slices()}), "underlying slices");
    is(join("", map {$_->seq} @{$align_slice->get_all_Slices($non_ref_species)->[0]->get_all_underlying_Slices(undef, undef, -1)}),
      $align_slice->get_all_Slices($non_ref_species)->[0]->subseq(undef, undef, -1), "underlying slices");

    done_testing();
};

done_testing();

exit();

=pod

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

=cut
