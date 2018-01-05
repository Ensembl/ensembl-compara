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

use Bio::EnsEMBL::Registry;


#
# This script demonstrates how to fetch a GenomicAlignBlock from a DNAFrag
# and then access each of the species sequences
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry->get_DBAdaptor('Multi', 'compara');

# get GenomeDB for human and mouse
my $humanGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("human");
my $mouseGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("mouse");

# get MethodLinkSpeciesSet for LASTZ_NET alignments between human and mouse
my $method_link_species_set = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
     fetch_by_method_link_type_GenomeDBs("LASTZ_NET", [$humanGDB, $mouseGDB]);

# get dnafrag for human chr 18
my $dnafrag = $comparaDBA->get_DnaFragAdaptor->fetch_by_GenomeDB_and_name($humanGDB, '18');

# get the alignments on a piece of the DnaFrag
my $genomic_align_blocks = $comparaDBA->get_GenomicAlignBlockAdaptor->
     fetch_all_by_MethodLinkSpeciesSet_DnaFrag($method_link_species_set, $dnafrag, 75550000, 75560000);
foreach my $this_genomic_align_block (@{$genomic_align_blocks}) {
  print "Bio::EnsEMBL::Compara::GenomicAlignBlock #", $this_genomic_align_block->dbID, "\n";
  print "=====================================================\n";
  print " length: ", $this_genomic_align_block->length, "; score: ", $this_genomic_align_block->score, "\n";
  my $all_genomic_aligns = $this_genomic_align_block->get_all_GenomicAligns();
  foreach my $this_genomic_align (@$all_genomic_aligns) {
    print "  - ",
      join(":",
          $this_genomic_align->dnafrag->genome_db->name,
          $this_genomic_align->dnafrag->coord_system_name,
          $this_genomic_align->dnafrag->name,
          $this_genomic_align->dnafrag_start,
          $this_genomic_align->dnafrag_end,
          $this_genomic_align->dnafrag_strand),
      "\n",
      $this_genomic_align->aligned_sequence, "\n\n";
  }
}

