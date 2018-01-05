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


my $gene_member_adaptor = $reg->get_adaptor ("Multi", "compara", "GeneMember");
my $gene_tree_adaptor   = $reg->get_adaptor ("Multi", "compara", "GeneTree");
my $cafe_tree_adaptor   = $reg->get_adaptor ("Multi", "compara", "CAFEGeneFamily");

my $member = $gene_member_adaptor->fetch_by_stable_id($gene_stable_id);
my $gene_tree = $gene_tree_adaptor->fetch_default_for_Member($member);
my $cafe_tree = $cafe_tree_adaptor->fetch_by_GeneTree($gene_tree);

print $member->stable_id, "\t";
print $gene_tree->stable_id, "\t";

die "No gene gain/loss tree for this gene\n" unless (defined $cafe_tree);

my $tree_fmt = '%{-s}%{x-}_%{N}:%{d}';
#my $tree_fmt = '%{s|x}_%{N}:%{d}';
print $cafe_tree->root->newick_format('ryo', $tree_fmt), "\t";
print $cafe_tree->pvalue_avg, "\n";

for my $node (@{$cafe_tree->root->get_all_nodes}) {
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




