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


## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');


# Get the Compara Adaptor for MethodLinkSpeciesSet
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");

my $pig_cow_synteny_mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_registry_aliases( "SYNTENY", ["pig", "cow"]);

## Get the GenomeDB for the pig genome
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "GenomeDB");

my $pig_genome_db = $genome_db_adaptor->fetch_by_registry_name("pig");

## Get the DnaFrag for pig chromosome 15
my $dnafrag_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "DnaFrag");

my $pig_dnafrag_15 = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($pig_genome_db, 15);

## Get all the pig-cow syntenic regions for pig chromosome 15 
my $synteny_region_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "SyntenyRegion");

my $all_synteny_regions = $synteny_region_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($pig_cow_synteny_mlss, $pig_dnafrag_15);

foreach my $this_synteny_region (@$all_synteny_regions) {
    my $these_dnafrag_regions = $this_synteny_region->get_all_DnaFragRegions();
    foreach my $this_dnafrag_region (@$these_dnafrag_regions) {
        print $this_dnafrag_region->dnafrag()->genome_db()->name(), ": ", $this_dnafrag_region->slice()->name(), "\n";
    }
    print "\n";
}

