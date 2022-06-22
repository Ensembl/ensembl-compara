#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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
# This script fetches the Compara gene gain/loss tree of PROSER1 (ENSG00000120685) gene.
# Prints the tree in Newick format and several parameters as well.
# Then, it traverses the tree giving information about each node of the tree.
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous',
);

my $gene_stable_id = 'ENSG00000120685';
my $genome_name = "homo_sapiens";

my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");
my $gene_tree_adaptor   = $reg->get_adaptor("Multi", "compara", "GeneTree");
my $cafe_tree_adaptor   = $reg->get_adaptor("Multi", "compara", "CAFEGeneFamily");
my $genome_db_adaptor   = $reg->get_adaptor("Multi", "compara", "GenomeDB");
print $cafe_tree_adaptor;
print $genome_db_adaptor;
my $genome = $genome_db_adaptor->fetch_by_name_assembly($genome_name);
print $genome->genome_db_id, "\n";
my $member = $gene_member_adaptor->fetch_by_stable_id_GenomeDB($gene_stable_id, $genome);
my $gene_tree = $gene_tree_adaptor->fetch_default_for_Member($member);
my $cafe_tree = $cafe_tree_adaptor->fetch_by_GeneTree($gene_tree);

# We will prune the tree down to these species
my $genome_dbs = $genome_db_adaptor->fetch_all_by_mixed_ref_lists(
    -SPECIES_LIST   => ['Zebrafish', 'oryzias_latipes'],
    -TAXON_LIST     => ['Primates', 'Galliformes'],
);
my %good_genome_db_ids = map {$_->dbID} @$genome_dbs;

print $member->stable_id, "\t";
print $gene_tree->stable_id, "\t";

die "No gene gain/loss tree for this gene\n" unless (defined $cafe_tree);

my $tree_fmt = '%{-s}%{x-}_%{N}:%{d}';

print $cafe_tree->root->newick_format('ryo', $tree_fmt), "\t";
print $cafe_tree->pvalue_avg, "\n";

# Tree pruning
my @nodes_to_remove = grep {!$good_genome_db_ids{$_->genome_db_id}} @{$cafe_tree->root->get_all_leaves};
my $pruned_tree = $cafe_tree->root->remove_nodes(\@nodes_to_remove);

for my $node (@{$pruned_tree->get_all_nodes}) {
  my $node_name = $node->taxon->name;
  my $node_n_members = $node->n_members;
  my $node_pvalue = $node->has_parent ? ($node->pvalue || 'NA') : 'birth';
  my $dynamics = "[no change]";
  if ($node->is_contraction) {
    $dynamics = "[contraction]";
  } elsif ($node->is_expansion) {
    $dynamics = "[expansion]";
  }
  print "$node_name => $node_n_members ($node_pvalue) $dynamics\n";
}
