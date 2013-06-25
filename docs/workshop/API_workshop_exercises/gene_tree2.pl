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
my $gene_member = $gene_member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000238344");

## Get the tree for this member
my $tree = $gene_tree_adaptor->fetch_default_for_Member($gene_member);

print "The tree contains the following genes:\n";
foreach my $leaf_gene (@{$tree->get_all_Members()}) {
## $tree->get_all_leaves() returns exactly the same list
#foreach my $leaf_gene (@{$tree->get_all_leaves()}) {
  print $leaf_gene->stable_id(), "\n";
}

