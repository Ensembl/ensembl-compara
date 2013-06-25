use strict;
use warnings;

use Bio::EnsEMBL::Registry;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the compara member adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get the compara homology adaptor
my $homology_adaptor = $reg->get_adaptor("Multi", "compara", "Homology");

## Get the compara member
my $gene_member = $gene_member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000229314");

## Get all the homologues in mouse
my $all_homologies = $homology_adaptor->fetch_all_by_Member($gene_member);

## For each homology
foreach my $this_homology (@{$all_homologies}) {

  ## print the description (type of homology) and the
  ## subtype (taxonomy level of the event: duplic. or speciation)
  print $this_homology->description(), " [", $this_homology->taxonomy_level(), "]\n";

  ## print the members in this homology
  my $gene_members = $this_homology->get_all_GeneMembers();
  foreach my $this_member (@{$gene_members}) {
    print $this_member->source_name(), " ", $this_member->stable_id(), " (", $this_member->genome_db()->name(()), ")\n";
  }
  print "\n";
}
