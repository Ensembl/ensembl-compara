#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the human gene adaptor
my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

## Get the compara member adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get all existing gene object with the name BRCA2
my $these_genes = $human_gene_adaptor->fetch_all_by_external_name('BRCA2');

## For each of these genes
foreach my $this_gene (@$these_genes) {
  print $this_gene->source, " ", $this_gene->stable_id, "\n";

  ## Get the compara member
  my $gene_member = $gene_member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE", $this_gene->stable_id);
  ## Print some info for this member
  $gene_member->print_member();
}
