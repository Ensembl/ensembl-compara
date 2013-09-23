use strict;
use warnings;

use Bio::EnsEMBL::Registry;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the human gene adaptor
my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

## Get the compara genemember adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get all existing gene object with the name FAM41C
my $these_genes = $human_gene_adaptor->fetch_all_by_external_name('FAM41C');

## For each of these genes
foreach my $this_gene (@{$these_genes}) {

  print "Found ", $this_gene->stable_id(), ": ", $this_gene->description(), "\n";

  ## Get the compara member
  my $gene_member = $gene_member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE", $this_gene->stable_id());

  ## Print some info for this member
  print "The member ", $gene_member->stable_id(), " is from the ", $gene_member->source_name(), " source.\n";
  print "  Its coordinates on chromosome ", $gene_member->chr_name(), " are: ", $gene_member->dnafrag_start(), "-", $gene_member->dnafrag_end(), "\n";

  ## The same can be achieved with:
  #$gene_member->print_member();
}
