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
# This scripts maps genomic positions between two genomes, thanks to
# the LASTZ alignment
#


my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org:5306');


my $alignment_type = "LASTZ_NET";
my $set_of_species = "Homo sapiens:Pan troglodytes";
my $reference_species = "human";

#get the required adaptors
my $method_link_species_set_adaptor = $reg->get_adaptor('Multi', 'compara', 'MethodLinkSpeciesSet');
my $genome_db_adaptor = $reg->get_adaptor('Multi', 'compara', 'GenomeDB');
my $align_slice_adaptor = $reg->get_adaptor('Multi', 'compara', 'AlignSlice');
my $slice_adaptor = $reg->get_adaptor($reference_species, 'core', 'Slice');

#get the genome_db objects for human and chimp
my $genome_dbs = $genome_db_adaptor->fetch_all_by_mixed_ref_lists(-SPECIES_LIST => [split(":", $set_of_species)]);

#get the method_link_secies_set for human-chimp blastz whole genome alignments
my $method_link_species_set =
	$method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
	$alignment_type, $genome_dbs);

die "need a file with human SNP positions \"chr:pos\" eg 6:136365469\n" unless ( scalar(@ARGV) and (-r $ARGV[0]) );

open(IN, $ARGV[0]) or die;

while(<IN>) {
	chomp;
	my ($seq_region, $snp_pos) = split(":", $_);
	my $query_slice = $slice_adaptor->fetch_by_region(undef, $seq_region, $snp_pos, $snp_pos);

	my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
		$query_slice, $method_link_species_set);

	my $chimp_slice = $align_slice->get_all_Slices("pan_troglodytes")->[0];

	my ($original_slice, $position) = $chimp_slice->get_original_seq_region_position(1);

	print "human ", join(":", $seq_region, $snp_pos), "\tchimp ", join (":", $original_slice->seq_region_name, $position), "\n";
}

