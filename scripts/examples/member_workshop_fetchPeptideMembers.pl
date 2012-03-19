#!/usr/bin/env perl

use strict;
use warnings;

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

## Get all existing gene object with the name CTDP1
my $these_genes = $human_gene_adaptor->fetch_all_by_external_name('CTDP1');

## For each of these genes
foreach my $this_gene (@$these_genes) {
  print $this_gene->source, " ", $this_gene->stable_id, ": ", $this_gene->description, "\n";

  ## Get the compara member
  my $member = $member_adaptor->fetch_by_source_stable_id(
      "ENSEMBLGENE", $this_gene->stable_id);
  ## Print some info for this member
  $member->print_member();

  ## Get all the peptide member for this gene member
  my $peptide_members = $member->get_all_peptide_Members();
  printf("fetched %d peptides (translated transcripts) for gene\n", scalar(@$peptide_members));
  foreach my $this_peptide_member (@$peptide_members) {

    ## Print some info for this protien member
    $this_peptide_member->print_member();
    printf("seq_length = %d\n", $this_peptide_member->seq_length);
    ## Print its sequence
    print $this_peptide_member->bioseq->seq(), "\n";
    ## Also, you can use:
    ## print $this_peptide_member->translation->seq(), "\n";
  }
}
