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

# Auto-configure the registry
Bio::EnsEMBL::Registry->load_registry_from_db(
	-host=>'ensembldb.ensembl.org', -user=>'anonymous', 
	-port=>'5306');

my $reference_species = "sus_scrofa";
my $non_reference_species = "bos_taurus";
my $reference_gene = "MSTN";

#get the required adaptors
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
        'Multi', 'compara', 'MethodLinkSpeciesSet');

my $align_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
        'Multi', 'compara', 'AlignSlice');

my $gene_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
	$reference_species, 'core', 'Gene');

#get the method_link_species_set for mammals-EPO
my $methodLinkSpeciesSet = $method_link_species_set_adaptor->
	fetch_by_method_link_type_species_set_name("EPO", "mammals");

#get the MSTN gene
my $mstn_genes = $gene_adaptor->fetch_all_by_external_name($reference_gene);

foreach my $mstn_gene ( @{ $mstn_genes } ) {
	print join(":", "GENE", $mstn_gene->external_name, $mstn_gene->stable_id), "\n";
	foreach my $exon ( @{ $mstn_gene->canonical_transcript()->get_all_Exons() } ) {
		print join(":", "EXON", $exon->stable_id), "\n";
		#get "core" slices for the pig regions containing the mstn exons
		my $exon_slice = $exon->slice->sub_Slice($exon->start,$exon->end,$exon->strand);
		#get a mammal-EPO align_slice object for each pig exon "core" slice
		my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
			$exon_slice, $methodLinkSpeciesSet);	
		#get the corresponding align_slice slice for pig and cow
		my $cow_alignSlice_slice = $align_slice->get_all_Slices($non_reference_species); 
		my $pig_alignSlice_slice = $align_slice->get_all_Slices($reference_species);
		#split the sequence strings 
		my @pig_seq = split("", $pig_alignSlice_slice->[0]->seq);
		my @cow_seq = split("", $cow_alignSlice_slice->[0]->seq);
		for(my$i=0;$i<@pig_seq;$i++) {
			if($pig_seq[$i] ne $cow_seq[$i]) {
				#get the original "core" slice and assembly position for each base where there is a
				#difference between pig and cow 	
				my($orig_pig_slice, $orig_pig_position) = 
					$pig_alignSlice_slice->[0]->get_original_seq_region_position(1+$i);
				my($orig_cow_slice, $orig_cow_position) = 
					$cow_alignSlice_slice->[0]->get_original_seq_region_position(1+$i);
				#split out the assembly name and seq_region name 
				my($pig_asembly, $pig_dnafrag) = (split(":", $orig_pig_slice->name))[1,2];
				my($cow_asembly, $cow_dnafrag) = (split(":", $orig_cow_slice->name))[1,2];
				print "  ", join(":", $pig_asembly, $pig_dnafrag, $orig_pig_position, $pig_seq[$i]), "\t";
				print join(":", $cow_seq[$i], $orig_cow_position, $cow_dnafrag, $cow_asembly), "\n";
			}
		}
	}
}


