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
#Bio::EnsEMBL::Registry->no_version_check(1);

# Auto-configure the registry
Bio::EnsEMBL::Registry->load_registry_from_db(
	-host=>'ensembldb.ensembl.org', -user=>'anonymous', 
	-port=>'5306');

# set up an AlignIO to format SimpleAlign output
my $alignIO = Bio::AlignIO->newFh(-interleaved => 0,
                                  -fh => \*STDOUT,
                                  -format => 'clustalw',
                                  -idlength => 20);



# We want to retrieve a small region of the primate EPO multiple alignment using a region of human MT as the reference.

# get a compara MethodLinkSpeciesSet adaptor
my $method_link_species_set_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor(
      "Multi", "compara", "MethodLinkSpeciesSet");


# get the method_link_species_set (data object) from the adaptor
my $methodLinkSpeciesSet = $method_link_species_set_adaptor->
	fetch_by_method_link_type_species_set_name("EPO", "mammals");


# define the start and end positions for the alignment
my ($ref_start, $ref_end) = (5065,5085);


# get a human **core** Slice adaptor
my $human_slice_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor(
      "human", "core", "Slice");


# get the **core** slice (data object) corresponding to the region of interest 
my $human_slice = $human_slice_adaptor->fetch_by_region(
    "chromosome", "MT", $ref_start, $ref_end);


# get a compara GenomicAlignBlock adaptor 
my $genomic_align_block_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor(
      "Multi", "compara", "GenomicAlignBlock");


# get a list-ref of (data objects) genomic_align_blocks
my $all_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
        $methodLinkSpeciesSet, $human_slice);

foreach my $genomic_align_block (@{$all_genomic_align_blocks}){
#print Dumper $genomic_align_block;
	my $restricted_genomic_align_block = $genomic_align_block->restrict_between_alignment_positions($ref_start, $ref_end);

	# get some information from the data object
	print $alignIO $restricted_genomic_align_block->get_SimpleAlign;
	
}

