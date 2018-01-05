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
# This script fetches the Compara tree of PAX6, identifies
# the PAX6 leaf, and a random zebrafish leaf. It prints the
# distances to these leaves from the root and their last
# common ancestor
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $human_gene_adaptor = $reg->get_adaptor ("Homo sapiens", "core", "Gene");
my $gene_member_adaptor = $reg->get_adaptor ("Multi", "compara", "GeneMember");
my $gene_tree_adaptor = $reg->get_adaptor ("Multi", "compara", "GeneTree");

my $genes = $human_gene_adaptor-> fetch_all_by_external_name('PAX6');

foreach my $gene (@$genes) {
  my $gene_member = $gene_member_adaptor-> fetch_by_stable_id($gene->stable_id);
  die "no members" unless (defined $gene_member);

  # Fetch the gene tree
  my $tree = $gene_tree_adaptor->fetch_default_for_Member($gene_member);
  next unless $tree;
  my $all_leaves = $tree->get_all_leaves();

  my $node_h;
  my $node_z;

  while (my $leaf = shift @$all_leaves) {
  	# finds a zebrafish gene
      $node_z = $leaf if ($leaf->taxon_id == 7955);
	# finds the query gene
	$node_h = $leaf if ($leaf->gene_member->stable_id eq $gene->stable_id);
  }
  print "human: ", $node_h->toString(), "\n";
  print "zebra: ", $node_z->toString(), "\n",

  print "root to human: ", $node_h->distance_to_ancestor($tree->root), "\n";
  print "root to zebra: ", $node_z->distance_to_ancestor($tree->root), "\n";

  my $ancestor = $node_z->find_first_shared_ancestor($node_h);
  print "lca: ";
  $ancestor->print_node;
  print "lca to human: ", $node_h->distance_to_ancestor($ancestor), "\n";
  print "lca to zebra: ", $node_z->distance_to_ancestor($ancestor), "\n";
  
}
