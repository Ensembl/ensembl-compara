#!/usr/bin/env perl

use strict;
use warnings;


#
# This script fetches the gene tree of a given human gene, and prints
# the list of all the genes, with their description, with a recursive
# approach
#

use Bio::EnsEMBL::Registry;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the human gene adaptor
my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

## Get the compara member adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get the compara homology adaptor
my $gene_tree_adaptor = $reg->get_adaptor("Multi", "compara", "GeneTree");

## Get all existing gene object with the name BRCA2
my $these_genes = $human_gene_adaptor->fetch_all_by_external_name('CTDP1');


## Will call recursively children() to go through all the branches
sub recursively_print_content {

  my $node = shift;

  ## Is it a leaf or an internal node ?
  if ($node->get_child_count > 0) {
    ## $node is still a node, so we can call go deeper
    foreach my $child_node (@{$node->children}) {
      recursively_print_content($child_node);
    }
  } else {
    ## Here, $node is a Member
    print $node->stable_id, "\n";
  }
}

## For each of these genes...
foreach my $this_gene (@$these_genes) {
  print "Using gene ", $this_gene->stable_id, "\n";
  ## Get the compara member
  my $gene_member = $gene_member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE", $this_gene->stable_id);

  ## Get the tree for this peptide (cluster_set_id = 1)
  my $tree = $gene_tree_adaptor->fetch_default_for_Member($gene_member);
  next unless (defined $tree);

  print "The tree contains the following genes:\n";
  recursively_print_content($tree->root);

}
