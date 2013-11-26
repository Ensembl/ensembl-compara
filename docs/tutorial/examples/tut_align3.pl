# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

my $query_species = 'human';
my $seq_region = '14';
my $seq_region_start = 75000000;
my $seq_region_end   = 75010000;

# Getting the Slice adaptor:
my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $query_species, 'core', 'Slice');

# Fetching a Slice object:
my $query_slice = $slice_adaptor->fetch_by_region(
    'toplevel',
    $seq_region,
    $seq_region_start,
    $seq_region_end);

# Fetching all the GenomicAlignBlock corresponding to this Slice from the pairwise alignments (LASTZ_NET)
# between human and mouse:
my $genomic_align_blocks =
    $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
      $human_mouse_lastz_net_mlss,
      $query_slice);

# We will then (usually) need to restrict the blocks to the required positions in the reference sequence 
# ($seq_region_start and $seq_region_end)

foreach my $genomic_align_block( @{ $genomic_align_blocks }) {
    my $restricted_gab = $genomic_align_block->restrict_between_reference_positions($seq_region_start, $seq_region_end);
}
