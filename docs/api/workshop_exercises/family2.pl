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


## Get the compara genemember adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get the compara family adaptor
my $family_adaptor = $reg->get_adaptor("Multi", "compara", "Family");


## Get the compara member
my $gene_member = $gene_member_adaptor->fetch_by_stable_id("ENSG00000283087");

## Get all the families
my $all_families = $family_adaptor->fetch_all_by_GeneMember($gene_member);

## For each family
foreach my $this_family (@{$all_families}) {
  print $this_family->description(), " (description score = ", $this_family->description_score(), ")\n";

  ## print the members in this family
  my $all_members = $this_family->get_all_Members();
  foreach my $this_member (@{$all_members}) {
    print $this_member->source_name(), " ", $this_member->stable_id(), " (", $this_member->taxon()->name(), ")\n";
  }
  print "\n";
}
