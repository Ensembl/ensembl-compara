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
my $human_gene_adaptor =
    $reg->get_adaptor("Homo sapiens", "core", "Gene");

## Get the compara member adaptor
my $member_adaptor =
    $reg->get_adaptor("Multi", "compara", "Member");

## Get the compara homology adaptor
my $protein_tree_adaptor =
    $reg->get_adaptor("Multi", "compara", "ProteinTree");

## Get all existing gene object with the name BRCA2
my $these_genes = $human_gene_adaptor->fetch_all_by_external_name('CTDP1');


## Will call recursively children() to go through all the branches
sub recursively_print_content {

  my $tree = shift;

  ## Is it a leaf or an internal node ?
  if ($tree->get_child_count > 0) {
    ## $tree is still a tree, so we can call go deeper
    foreach my $child_tree (@{$tree->children}) {
      recursively_print_content($child_tree);
    }
  } else {
    ## Here, $tree is a Member
    print $tree->stable_id, "\n";
  }
}

## For each of these genes...
foreach my $this_gene (@$these_genes) {
  print "Using gene ", $this_gene->stable_id, "\n";
  ## Get the compara member
  my $member = $member_adaptor->fetch_by_source_stable_id(
      "ENSEMBLGENE", $this_gene->stable_id);

  ## Get the canonical peptide: the gene trees are built using these
  my $canonical_peptide = $member->get_canonical_peptide_Member;
  print "Canonical peptide is: ", $canonical_peptide->stable_id, "\n";

  ## Get the tree for this peptide (cluster_set_id = 1)
  my $tree = $protein_tree_adaptor->
      fetch_by_Member_root_id($canonical_peptide);
  return 0 unless (defined $tree);

  print "The tree contains the following genes:\n";
  recursively_print_content($tree);

}
