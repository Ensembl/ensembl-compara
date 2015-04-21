# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

## Get the compara member adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get the compara gene tree adaptor
my $gene_tree_adaptor = $reg->get_adaptor("Multi", "compara", "GeneTree");

## Get the compara member
my $gene_member = $gene_member_adaptor->fetch_by_stable_id("ENSDARG00000003399");

## Get the tree for this member
my $tree = $gene_tree_adaptor->fetch_default_for_Member($gene_member);

## Tip: will make the traversal of the tree faster
$tree->preload();

## Will iterate over all the nodes of a tree
sub count_duplications_iterative {
  my $root = shift;

  my $n_dup = 0;
  foreach my $node (@{$root->get_all_nodes()}) {
    if ((not $node->is_leaf()) and ($node->get_tagvalue('node_type') eq 'duplication')) {
      print "There is a duplication at the taxon '", $node->get_tagvalue('taxon_name'), "'\n";
      $n_dup++;
    }
  }

  return $n_dup;
}


## Will call recursively children() to go through all the branches
sub count_duplications_recursive {
  my $node = shift;

  ## Is it a leaf or an internal node ?
  if ($node->is_leaf()) {
    return 0;
  }

  my $s = 0;
  
  if ($node->get_tagvalue('node_type') eq 'duplication') {
    $s++;
    print "There is a duplication at the taxon '", $node->get_tagvalue('taxon_name'), "'\n";
  }

  foreach my $child_node (@{$node->children()}) {
    $s += count_duplications_recursive($child_node);
  }

  return $s;
}

print "The tree ", $tree->stable_id(), " contains ", count_duplications_recursive($tree->root), " duplication nodes.\n";
print "The tree ", $tree->stable_id(), " contains ", count_duplications_iterative($tree->root), " duplication nodes.\n";

