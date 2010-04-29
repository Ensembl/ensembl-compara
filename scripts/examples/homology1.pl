#!/software/bin/perl
use strict;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_db
    (-host=>"ensembldb.ensembl.org", 
     -user=>"anonymous",
     -db_version=>58);

my $human_gene_adaptor =  Bio::EnsEMBL::Registry->get_adaptor("Homo sapiens", "core", "Gene");
my $member_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "Member");
my $homology_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "Homology");

my $external_name = 'BRCA2';
my $genes = $human_gene_adaptor->fetch_all_by_external_name($external_name);
foreach my $gene (@$genes) {
  my $member = $member_adaptor->
  fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  next unless defined($member);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);
  my $biotype = $gene->biotype;
  foreach my $this_homology (@$all_homologies) {
    $this_homology->print_homology;
  }
}

1;
