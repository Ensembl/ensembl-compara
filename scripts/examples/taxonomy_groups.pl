#!/usr/bin/perl
use strict;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_db
  (-host=>"ensembldb.ensembl.org", 
   -user=>"anonymous");

my $taxonDBA =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "NCBITaxon");

my @list_of_species = ("Homo sapiens","Mus musculus","Drosophila melanogaster","Caenorhabditis elegans");
my $root;
foreach my $species_name (@list_of_species) {
  my $taxon = $taxonDBA->fetch_node_by_name($species_name);
  next unless defined($taxon);
  unless (defined($taxon->binomial)) {
    print STDERR "WARN: No binomial for $species_name\n";
    next;
  }
  my $taxon_name = $taxon->name;
  my $taxon_id = $taxon->taxon_id;
  print STDERR "  $taxon_name [$taxon_id]\n";
  $taxon->release_children;

  $root = $taxon->root unless($root);
  $root->merge_node_via_shared_ancestor($taxon);
}
$root = $root->minimize_tree;
print "MRCA is ", $root->name, "\t", $root->taxon_id, "\n";
$root->print_tree(10);

1;
