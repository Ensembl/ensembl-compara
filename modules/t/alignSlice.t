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

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

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

my $ref_species = "homo_sapiens";

## Connect to core DB specified in the MultiTestDB.conf file
my $species_db;

## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (reverse sort @$species) {
  $species_db->{$this_species} = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  die if (!$species_db->{$this_species});
}

#Set up adaptors
my $slice_adaptor = $species_db->{$ref_species}->get_DBAdaptor("core")->get_SliceAdaptor();
my $align_slice_adaptor = $compara_dba->get_AlignSliceAdaptor();
my $genomic_align_adaptor = $compara_dba->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();

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
my $slice_start = 31500000;
my $slice_end = 32000000;

my $method_type = "LASTZ_NET";
my $mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_registry_aliases($method_type, ["homo_sapiens", "mus_musculus"]);

my $human_chimp_lastznet_mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_registry_aliases(
        "LASTZ_NET",
        [ "homo_sapiens", "pan_troglodytes" ]
    );

#
# New(void) method
#
subtest "Test Bio::EnsEMBL::Compara::AlignSlice new(void) method", sub {
  my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice();
  isa_ok($align_slice, "Bio::EnsEMBL::Compara::AlignSlice", "check object");

  done_testing();
};

#
# New(ALL) method
#
subtest "Test Bio::EnsEMBL::Compara::GenomicAlign new(ALL) method", sub {

    my $gab_forward_id = 5990000047741;
    my $sth = $compara_dba->dbc->prepare("SELECT genomic_align_id
    FROM genomic_align WHERE genomic_align_block_id=$gab_forward_id");
    
    $sth->execute();
    my $genomic_aligns;
    while (my $genomic_align_id = $sth->fetchrow_array) {
        my $ga = $genomic_align_adaptor->fetch_by_dbID($genomic_align_id);
        push @{$genomic_aligns->{$ga->dnafrag->genome_db->name}}, $ga;
   }
    my $ref_species = "homo_sapiens";
    my $ref_ga = $genomic_aligns->{$ref_species}->[0];

    my $slice = $slice_adaptor->fetch_by_region(
                                                $ref_ga->dnafrag->coord_system_name,
                                                $ref_ga->dnafrag->name,
                                                $ref_ga->dnafrag_start,
                                                $ref_ga->dnafrag_end,
                                                1
                                               );
    #LASTZ
    my $gabs = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice, undef, undef, 1);
    
    my $expanded = 1;
    my $solve_overlapping = 0;
    my $preserve_blocks = 0;
    my $species_order;

    my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice(-adaptor => $align_slice_adaptor,
                                                            -reference_slice => $slice,
                                                            -Genomic_Align_Blocks => $gabs, 
                                                            -method_link_species_set => $mlss,
                                                            -expanded => $expanded,
                                                            -solve_overlapping => $solve_overlapping,
                                                            -preserve_blocks => $preserve_blocks,
                                                            -species_order => $species_order,
                                                           );

    #Not many getter functions. Can only set many fields via the new method
    isa_ok($align_slice, "Bio::EnsEMBL::Compara::AlignSlice", "check object");
    is($align_slice->adaptor, $align_slice_adaptor, "adaptor");
    is($align_slice->reference_Slice, $slice, "reference_slice");
    is($align_slice->get_MethodLinkSpeciesSet, $mlss, "mlss");

    done_testing();
};

subtest "Test attributes of Bio::EnsEMBL::Compara::AlignSlice::Slice objects... expanded", sub {
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
  my $slice = $slice_adaptor->fetch_by_region(
                                              $slice_coord_system_name,
                                              $slice_seq_region_name,
                                              $slice_start,
                                              $slice_end,
                                              1
                                             );
  isa_ok($slice, "Bio::EnsEMBL::Slice", "check object");
  
  my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $mlss, "expanded");

  #coord_system->name
  is($align_slice->reference_Slice->coord_system->name, "chromosome");
  is($align_slice->get_all_Slices($ref_species)->[0]->coord_system->name, "align_slice");
  is($align_slice->get_all_Slices($non_ref_species)->[0]->coord_system->name, "align_slice");

  #coord_system_name
  is($align_slice->reference_Slice->coord_system_name, "chromosome");
  is($align_slice->get_all_Slices($ref_species)->[0]->coord_system_name, "align_slice");
  is($align_slice->get_all_Slices($non_ref_species)->[0]->coord_system_name, "align_slice");

  #coord_system->version
  like($align_slice->reference_Slice->coord_system->version, '/^GRCh\d+$/');
  like($align_slice->get_all_Slices($ref_species)->[0]->coord_system->version,
      "/^chromosome_GRCh\\d+_${slice_seq_region_name}_${slice_start}_${slice_end}_1\\+/");
  like($align_slice->get_all_Slices($ref_species)->[0]->coord_system->version,
      '/\+LASTZ_NET\(\"homo_sapiens\"\+\"pan_troglodytes\"\)\+/');
  like($align_slice->get_all_Slices($ref_species)->[0]->coord_system->version,
      "/\\+expanded/");
  like($align_slice->get_all_Slices($non_ref_species)->[0]->coord_system->version,
      "/^chromosome_GRCh\\d+_${slice_seq_region_name}_${slice_start}_${slice_end}_1\\+/");
  like($align_slice->get_all_Slices($non_ref_species)->[0]->coord_system->version,
      '/\+LASTZ_NET\(\"homo_sapiens\"\+\"pan_troglodytes\"\)\+/');
  like($align_slice->get_all_Slices($non_ref_species)->[0]->coord_system->version,
      "/\\+expanded/");

  #seq_region_name
  is($align_slice->reference_Slice->seq_region_name, $slice_seq_region_name);
  is($align_slice->get_all_Slices($ref_species)->[0]->seq_region_name, $ref_species);
  is($align_slice->get_all_Slices($non_ref_species)->[0]->seq_region_name, $non_ref_species);

  #seq_region_length
  my $seq = $align_slice->get_all_Slices($ref_species)->[0]->seq;
  my $gaps = $seq =~ tr/\-/\-/;
  is($align_slice->get_all_Slices($ref_species)->[0]->seq_region_length, ($slice_end-$slice_start+1+$gaps));
  is($align_slice->get_all_Slices($non_ref_species)->[0]->seq_region_length, ($slice_end-$slice_start+1+$gaps));

  #start
  is($align_slice->get_all_Slices($ref_species)->[0]->start, 1);
  is($align_slice->get_all_Slices($non_ref_species)->[0]->start, 1);

  #end
  is($align_slice->get_all_Slices($ref_species)->[0]->end, ($slice_end-$slice_start+1+$gaps));
  is($align_slice->get_all_Slices($non_ref_species)->[0]->end, ($slice_end-$slice_start+1+$gaps));

  #strand
  is($align_slice->get_all_Slices($ref_species)->[0]->strand, 1);
  is($align_slice->get_all_Slices($non_ref_species)->[0]->strand, 1);

  #name
  is($align_slice->get_all_Slices($ref_species)->[0]->name, join(":",
          $align_slice->get_all_Slices($ref_species)->[0]->coord_system_name,
          $align_slice->get_all_Slices($ref_species)->[0]->coord_system->version,
          $align_slice->get_all_Slices($ref_species)->[0]->seq_region_name,
          $align_slice->get_all_Slices($ref_species)->[0]->start,
          $align_slice->get_all_Slices($ref_species)->[0]->end,
          $align_slice->get_all_Slices($ref_species)->[0]->strand)
      );

  is($align_slice->get_all_Slices($non_ref_species)->[0]->name, join(":",
          $align_slice->get_all_Slices($non_ref_species)->[0]->coord_system_name,
          $align_slice->get_all_Slices($non_ref_species)->[0]->coord_system->version,
          $align_slice->get_all_Slices($non_ref_species)->[0]->seq_region_name,
          $align_slice->get_all_Slices($non_ref_species)->[0]->start,
          $align_slice->get_all_Slices($non_ref_species)->[0]->end,
          $align_slice->get_all_Slices($non_ref_species)->[0]->strand)
      );


    done_testing();
};

subtest "Test attributes of Bio::EnsEMBL::Compara::AlignSlice::Slice objects... condensed", sub {
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
  my $slice = $slice_adaptor->fetch_by_region(
                                              $slice_coord_system_name,
                                              $slice_seq_region_name,
                                              $slice_start,
                                              $slice_end,
                                              1
                                             );
  isa_ok($slice, "Bio::EnsEMBL::Slice", "check object");
  
  my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $mlss);

  #coord_system->name
  is($align_slice->reference_Slice->coord_system->name, "chromosome");
  is($align_slice->get_all_Slices($ref_species)->[0]->coord_system->name, "align_slice");
  is($align_slice->get_all_Slices($non_ref_species)->[0]->coord_system->name, "align_slice");

  #coord_system_name
  is($align_slice->reference_Slice->coord_system_name, "chromosome");
  is($align_slice->get_all_Slices($ref_species)->[0]->coord_system_name, "align_slice");
  is($align_slice->get_all_Slices($non_ref_species)->[0]->coord_system_name, "align_slice");

  #coord_system->version
  like($align_slice->reference_Slice->coord_system->version, '/^GRCh\d+$/');
  like($align_slice->get_all_Slices($ref_species)->[0]->coord_system->version,
      "/^chromosome_GRCh\\d+_${slice_seq_region_name}_${slice_start}_${slice_end}_1\\+/");
  like($align_slice->get_all_Slices($ref_species)->[0]->coord_system->version,
      '/\+LASTZ_NET\(\"homo_sapiens\"\+\"pan_troglodytes\"\)\+/');
  like($align_slice->get_all_Slices($ref_species)->[0]->coord_system->version,
      "/\\+condensed/");
  like($align_slice->get_all_Slices($non_ref_species)->[0]->coord_system->version,
      "/^chromosome_GRCh\\d+_${slice_seq_region_name}_${slice_start}_${slice_end}_1\\+/");
  like($align_slice->get_all_Slices($non_ref_species)->[0]->coord_system->version,
      '/\+LASTZ_NET\(\"homo_sapiens\"\+\"pan_troglodytes\"\)\+/');
  like($align_slice->get_all_Slices($non_ref_species)->[0]->coord_system->version,
      "/\\+condensed/");

  #seq_region_name
  is($align_slice->reference_Slice->seq_region_name, $slice_seq_region_name);
  is($align_slice->get_all_Slices($ref_species)->[0]->seq_region_name, $ref_species);
  is($align_slice->get_all_Slices($non_ref_species)->[0]->seq_region_name, $non_ref_species);

  #seq_region_length
  my $seq = $align_slice->get_all_Slices($ref_species)->[0]->seq;
  is($align_slice->get_all_Slices($ref_species)->[0]->seq_region_length, ($slice_end-$slice_start+1));
  is($align_slice->get_all_Slices($non_ref_species)->[0]->seq_region_length, ($slice_end-$slice_start+1));

  #start
  is($align_slice->get_all_Slices($ref_species)->[0]->start, 1);
  is($align_slice->get_all_Slices($non_ref_species)->[0]->start, 1);

  #end
  is($align_slice->get_all_Slices($ref_species)->[0]->end, ($slice_end-$slice_start+1));
  is($align_slice->get_all_Slices($non_ref_species)->[0]->end, ($slice_end-$slice_start+1));

  #strand
  is($align_slice->get_all_Slices($ref_species)->[0]->strand, 1);
  is($align_slice->get_all_Slices($non_ref_species)->[0]->strand, 1);

  #name
  is($align_slice->get_all_Slices($ref_species)->[0]->name, join(":",
          $align_slice->get_all_Slices($ref_species)->[0]->coord_system_name,
          $align_slice->get_all_Slices($ref_species)->[0]->coord_system->version,
          $align_slice->get_all_Slices($ref_species)->[0]->seq_region_name,
          $align_slice->get_all_Slices($ref_species)->[0]->start,
          $align_slice->get_all_Slices($ref_species)->[0]->end,
          $align_slice->get_all_Slices($ref_species)->[0]->strand)
      );

  is($align_slice->get_all_Slices($non_ref_species)->[0]->name, join(":",
          $align_slice->get_all_Slices($non_ref_species)->[0]->coord_system_name,
          $align_slice->get_all_Slices($non_ref_species)->[0]->coord_system->version,
          $align_slice->get_all_Slices($non_ref_species)->[0]->seq_region_name,
          $align_slice->get_all_Slices($non_ref_species)->[0]->start,
          $align_slice->get_all_Slices($non_ref_species)->[0]->end,
          $align_slice->get_all_Slices($non_ref_species)->[0]->strand)
      );


    done_testing();
};

done_testing();

