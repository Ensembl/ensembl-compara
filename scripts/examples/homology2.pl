#!/usr/local/bin/perl
use strict;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_db(-host=>"ensembldb.ensembl.org", -user=>"anonymous", -db_version=>'42');

my $human_gene_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Homo sapiens", "core", "Gene");

my $member_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "Member");

my $homology_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "Homology");

my $proteintree_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "ProteinTree");

my $mlss_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "MethodLinkSpeciesSet");

my $brca2_genes = $human_gene_adaptor->fetch_all_by_external_name('BRCA2');

foreach my $brca2_gene (@$brca2_genes) {
  my $member = $member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE",
      $brca2_gene->stable_id);
  die "no members" unless (defined $member);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);
  my $proteintree =  $proteintree_adaptor->fetch_by_Member_root_id($member);

  foreach my $leaf (@{$proteintree->get_all_leaves}) {
      print $leaf->description, "\n";
  }
  my $newick = $proteintree->newick_format();
  my $nhx = $proteintree->nhx_format("gene_id");
  $nhx = $proteintree->nhx_format("protein_id");
  $nhx = $proteintree->nhx_format("transcript_id");
}
