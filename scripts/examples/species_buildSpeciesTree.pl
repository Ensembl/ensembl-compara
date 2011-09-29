#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script creates a species tree for a given list of species using
# the NCBITaxon facilities of the Compara database
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $taxonDBA = $reg->get_adaptor("Compara", "compara", "NCBITaxon");

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

