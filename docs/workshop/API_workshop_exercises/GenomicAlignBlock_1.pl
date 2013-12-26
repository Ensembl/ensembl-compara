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

use strict;
use warnings;
use Data::Dumper;
use Bio::AlignIO;

use Bio::EnsEMBL::Registry;

#Auto-configure the registry
Bio::EnsEMBL::Registry->load_registry_from_db(
	-host=>"ensembldb.ensembl.org", -user=>"anonymous",
        -port=>'5306');


# Get the Compara Adaptor for MethodLinkSpeciesSets
my $method_link_species_set_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor(
      "Multi", "compara", "MethodLinkSpeciesSet");

my $methodLinkSpeciesSet = $method_link_species_set_adaptor->
	fetch_by_method_link_type_registry_aliases("LASTZ_NET", ["pig", "cow"]);

# Define the start and end positions for the alignment
my ($pig_start, $pig_end) = (105734307,105739335);

# Get the pig *core* Adaptor for Slices
my $pig_slice_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor(
      "sus_scrofa", "core", "Slice");

# Get the slice corresponding to the region of interest
my $pig_slice = $pig_slice_adaptor->fetch_by_region(
    "chromosome", 15, $pig_start, $pig_end);

# Get the Compara Adaptor for GenomicAlignBlocks
my $genomic_align_block_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor(
      "Multi", "compara", "GenomicAlignBlock");

# The fetch_all_by_MethodLinkSpeciesSet_Slice() returns a ref.
# to an array of GenomicAlingBlock objects (pig is the reference species) 
my $all_genomic_align_blocks = $genomic_align_block_adaptor->
    fetch_all_by_MethodLinkSpeciesSet_Slice(
        $methodLinkSpeciesSet, $pig_slice);

# set up an AlignIO to format SimpleAlign output
my $alignIO = Bio::AlignIO->newFh(-interleaved => 0,
                                  -fh => \*STDOUT,
                                  -format => 'clustalw',
                                  -idlength => 20);

# print the restricted alignments
foreach my $genomic_align_block( @{ $all_genomic_align_blocks }) {
	my $restricted_gab = $genomic_align_block->restrict_between_reference_positions($pig_start, $pig_end);
	print $alignIO $restricted_gab->get_SimpleAlign;
}
