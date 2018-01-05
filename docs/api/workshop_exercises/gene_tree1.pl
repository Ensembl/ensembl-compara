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

## Get the compara gene tree adaptor
my $gene_tree_adaptor = $reg->get_adaptor("Multi", "compara", "GeneTree");

## Get the tree with this stable id
my $tree = $gene_tree_adaptor->fetch_by_stable_id('ENSGT00390000003602');

## Print tree in newick format
print $tree->newick_format('simple'),"\n\n";

## Print tree in nhx format
print $tree->nhx_format('full'),"\n\n";

## Print tree in ASCII format
$tree->print_tree(10);

