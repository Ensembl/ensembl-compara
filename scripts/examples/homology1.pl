use strict;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_db(-host=>"ensembldb.ensembl.org", -user=>"anonymous", -verbose=>'0');

my $human_gene_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Homo sapiens", "core", "Gene");

my $member_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "Member");

my $homology_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "Homology");

my $genes = $human_gene_adaptor->fetch_all_by_external_name('CTDP1');

foreach my $gene (@$genes) {
  my $member = $member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE",
      $gene->stable_id);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);

  foreach my $this_homology (@$all_homologies) {
    my $description = $this_homology->description;
    print $description, " ";
    next unless ($description =~ /one2one/);
    my $all_member_attributes = $this_homology->get_all_Member_Attribute();
    my $first_found = 0;
    foreach my $this_member_attribute (@$all_member_attributes) {
      my ($this_member, $this_attribute) = @$this_member_attribute;
      my $this_member_stable_id = $this_member->stable_id;
      printf "  %-20s %-25s", $this_member->source_name, $this_member_stable_id;
      print " ", $this_member->chr_name, " : ", $this_member->chr_start, "-",
          $this_member->chr_end;
      print "\n";
    }
  }
}
