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

## Get the compara gene member adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get the compara gene tree adaptor
my $gene_tree_adaptor = $reg->get_adaptor("Multi", "compara", "GeneTree");

## Get the compara member
my $gene_member = $gene_member_adaptor->fetch_by_stable_id("ENSG00000238344");

## Get the tree for this member
my $tree = $gene_tree_adaptor->fetch_default_for_Member($gene_member);

print "The tree contains the following genes:\n";
foreach my $leaf_gene (@{$tree->get_all_Members()}) {
## $tree->get_all_leaves() returns exactly the same list
#foreach my $leaf_gene (@{$tree->get_all_leaves()}) {
  print $leaf_gene->stable_id(), "\n";
}

## BioPerl alignment
my $simple_align = $tree->get_SimpleAlign(-append_taxon_id => 1);
my $alignIO = Bio::AlignIO->newFh(-format => "clustalw");
print $alignIO $simple_align;

