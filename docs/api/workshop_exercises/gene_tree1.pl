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

