#!/usr/local/bin/perl
use strict;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_db
  (-host=>"ensembldb.ensembl.org", 
   -user=>"anonymous", 
   -db_version=>'58');

my $human_gene_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Homo sapiens", "core", "Gene");
my $member_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Compara", "compara", "Member");
my $homology_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Compara", "compara", "Homology");
my $proteintree_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Compara", "compara", "ProteinTree");
my $mlss_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Compara", "compara", "MethodLinkSpeciesSet");

my $genes = $human_gene_adaptor->
  fetch_all_by_external_name('TEX12');

foreach my $gene (@$genes) {
  my $member = $member_adaptor->
    fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  die "no members" unless (defined $member);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);

  # Fetch the proteintree
  my $proteintree =  $proteintree_adaptor->
    fetch_by_gene_Member_root_id($member);
  my @sitewise_dnds_values = @{$proteintree->get_SitewiseOmega_values};
  my $conservation_string;
  printf ("%5s %10s %5s %12s\n","alnpos", "type", "omega", "CI(lower upper)\n");
  foreach my $site (@sitewise_dnds_values) {
    my $type = $site->type;
    my $omega = $site->omega;
    my $omega_upper = $site->omega_upper;
    my $omega_lower = $site->omega_lower;
    my $aln_position = $site->aln_position;
    printf ("%5d %10s %5f (%5f %5f)\n",$aln_position, $type, $omega, $omega_lower, $omega_upper);
  }
}
