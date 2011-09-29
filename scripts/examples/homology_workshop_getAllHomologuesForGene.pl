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

## Get the compara homology adaptor
my $homology_adaptor =
    $reg->get_adaptor("Multi", "compara", "Homology");

## Get all existing gene object with the name CNTROB
my $these_genes = $human_gene_adaptor->fetch_all_by_external_name('CNTROB');

## For each of these genes...
foreach my $this_gene (@$these_genes) {
  ## Get the compara member
  my $member = $member_adaptor->fetch_by_source_stable_id(
      "ENSEMBLGENE", $this_gene->stable_id);

  ## Get all the homologues
  my $all_homologies = $homology_adaptor->fetch_all_by_Member($member);
  ## Get all the homologues in mouse
  # my $all_homologies = $homology_adaptor->fetch_all_by_Member_paired_species($member, "mus_musculus");

  ## For each homology
  foreach my $this_homology (@$all_homologies) {
    ## print the description (type of homology) and the
    ## subtype (taxonomy level of the event: duplic. or speciation)
    print $this_homology->description, " [", $this_homology->subtype, "]\n";

    ## print the members in this homology
    my $members = $this_homology->get_all_Members();
    foreach my $this_member (@$members) {
      print $this_member->source_name, " ",
          $this_member->stable_id, " (",
          $this_member->genome_db->name, ")\n";
    }
    
    ## Or use the built-in method
    $this_homology->print_homology;
    
    print "\n";
  }
}
