use strict;
use warnings;


#
# This script fetches the gene tree of a given human gene, and prints
# the tree in various formats
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
my $these_genes = $human_gene_adaptor->fetch_all_by_external_name('BRCA2');

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

  ## Print tree in newick format
  print $tree->newick_simple_format,"\n\n";
  print $tree->newick_format("display_label_composite"), "\n\n";
  print $tree->nhx_format("display_label_composite"), "\n\n";

  ## Print tree in ASCII format
  $tree->print_tree(10);
}
