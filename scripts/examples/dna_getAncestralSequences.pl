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
use Bio::AlignIO;


#
# This script demonstrates how to fetch a GenomicAlignBlock from a DNAFrag
# and then access each of the species sequences and their ancestral
# sequences too
#

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');


# Get the Compara Adaptor for MethodLinkSpeciesSet
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");

# Get the method_link_species_set for the alignments
my $methodLinkSpeciesSet = $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name('EPO', 'mammals');

# Define the start and end positions for the alignment
my ($pig_start, $pig_end) = (105735017,105735022);

# Get the pig *core* Adaptor for Slices
my $pig_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor("pig", "core", "Slice");

# Get the slice corresponding to the region of interest
my $pig_slice = $pig_slice_adaptor->fetch_by_region("chromosome", 15, $pig_start, $pig_end);

# Get the Compara Adaptor for GenomicAlignBlocks
my $genomic_align_tree_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "GenomicAlignTree");

# The fetch_all_by_MethodLinkSpeciesSet_Slice() returns a ref.
# to an array of GenomicAlingBlock objects (pig is the reference species) 
my $all_genomic_align_trees = $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($methodLinkSpeciesSet, $pig_slice);

# set up an AlignIO to format SimpleAlign output
my $alignIO = Bio::AlignIO->newFh(-interleaved => 0,
                                  -fh => \*STDOUT,
                                  -format => 'clustalw',
                                  -idlength => 20);

# print the restricted alignments
foreach my $genomic_align_tree( @{ $all_genomic_align_trees }) {
  my $restricted_gat = $genomic_align_tree->restrict_between_reference_positions($pig_start, $pig_end);
  print "Bio::EnsEMBL::Compara::GenomicAlignBlock #", $genomic_align_tree->dbID, "\n";
  print "=====================================================\n";
  print " length: ", $restricted_gat->length, "\n";

  $restricted_gat->annotate_node_type();
  foreach my $node (@{$restricted_gat->get_all_nodes()}) {
    # We can assume there is exactly 1 GenomicAlign per node
    my $this_genomic_align = $node->get_all_genomic_aligns_for_node->[0];
    print "  - ",
      join(":",
          $this_genomic_align->dnafrag->genome_db->name,
          $this_genomic_align->dnafrag->coord_system_name,
          $this_genomic_align->dnafrag->name,
          $this_genomic_align->dnafrag_start,
          $this_genomic_align->dnafrag_end,
          $this_genomic_align->dnafrag_strand),
      $node->is_leaf ? '' : "\n    ".$node->name,
      "\n",
      $this_genomic_align->aligned_sequence, "\n\n";
  }
}

