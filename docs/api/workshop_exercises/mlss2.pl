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

# Get the Compara Adaptor for MethodLinkSpeciesSets
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor( "Multi", "compara", "MethodLinkSpeciesSet");

# fetch_all() method returns a array ref.
my $all_mlss = $mlssa->fetch_all();

my (%CT, $total_count);

foreach my $method_link_species_set (@{ $all_mlss }){
	$CT{ $method_link_species_set->method()->type() }++;
	$total_count++;
}

print "number of analyses: ", $total_count, "\n";
foreach my $method_link_type (keys %CT){
	print $method_link_type, ": ", $CT{$method_link_type}, "\n";
}
