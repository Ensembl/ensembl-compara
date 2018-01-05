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
use Bio::EnsEMBL::Utils::Exception qw(throw);

#
# Simple example to show how to get conservation scores for a slice.
#

my $reg = "Bio::EnsEMBL::Registry";
my $species = "Homo sapiens";
my $seq_region = "17";
my $seq_region_start = 33692982;
my $seq_region_end =   33693481;

$reg->load_registry_from_db(
      -host => "ensembldb.ensembl.org",
      -user => "anonymous",
);

#get method_link_species_set adaptor
my $mlss_adaptor = $reg->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");

#get method_link_species_set object for gerp conservation scores for mammals
my $mlss = $mlss_adaptor->fetch_by_method_link_type_species_set_name("GERP_CONSERVATION_SCORE", "mammals");

throw("Unable to find method_link_species_set") if (!defined($mlss));

#get slice adaptor for $species
my $slice_adaptor = $reg->get_adaptor($species, 'core', 'Slice');
throw("Registry configuration file has no data for connecting to <$species>") if (!$slice_adaptor);

#create slice 
my $slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region, $seq_region_start, $seq_region_end);
throw("No Slice can be created with coordinates $seq_region:$seq_region_start-$seq_region_end") if (!$slice);

#get conservation score adaptor
my $cs_adaptor = $reg->get_adaptor("Multi", 'compara', 'ConservationScore');			
#To get one score per base in the slice, must set display_size to the size of
#the slice.
my $display_size = $slice->end - $slice->start + 1; 
my $scores = $cs_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice, $display_size);

print "number of scores " . @$scores . "\n";

#print out the position, observed, expected and difference scores.
foreach my $score (@$scores) {
    if (defined $score->diff_score) {
	printf("position %d observed %.4f expected %.4f difference %.4f\n",  $score->position, $score->observed_score, $score->expected_score, $score->diff_score);
    }
}

