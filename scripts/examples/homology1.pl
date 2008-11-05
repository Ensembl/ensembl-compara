#!/usr/local/bin/perl
use strict;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_db
    (-host=>"ensembldb.ensembl.org", 
     -user=>"anonymous");
my $human_gene_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Homo sapiens", "core", "Gene");
my $member_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Compara", "compara", "Member");
my $homology_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Compara", "compara", "Homology");

my $genes = $human_gene_adaptor->
   fetch_all_by_external_name('CTDP1');

foreach my $gene (@$genes) {
  my $member = $member_adaptor->
  fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);

  foreach my $this_homology (@$all_homologies) {
    my $description = $this_homology->description;
    next unless ($description =~ /one2one/); # if only one2one wanted
    my $all_member_attributes = 
    $this_homology->get_all_Member_Attribute();
    my $first_found = 0;
    foreach my $ma (@$all_member_attributes) {
      1;#??
      my ($mb, $attr) = @$ma;
      my $label = $mb->display_label || $mb->stable_id;
      print $mb->genome_db->short_name, ",", $label, "\t";
    }
    print "\n";
  }
}
