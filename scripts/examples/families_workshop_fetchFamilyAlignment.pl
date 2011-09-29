use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::SimpleAlign;
use Bio::AlignIO;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the human gene adaptor
my $human_gene_adaptor =
    $reg->get_adaptor("Homo sapiens", "core", "Gene");

## Get the compara member adaptor
my $member_adaptor =
    $reg->get_adaptor("Multi", "compara", "Member");

## Get the compara family adaptor
my $family_adaptor =
    $reg->get_adaptor("Multi", "compara", "Family");

## Get all existing gene object with the name HBEGF
my $these_genes = $human_gene_adaptor->fetch_all_by_external_name('HBEGF');

## For each of these genes...
foreach my $this_gene (@$these_genes) {
  ## Get the compara member
  my $member = $member_adaptor->fetch_by_source_stable_id(
      "ENSEMBLGENE", $this_gene->stable_id);

  ## Get all the families
  my $all_families = $family_adaptor->fetch_all_by_Member($member);

  ## For each family
  foreach my $this_family (@$all_families) {
    print $this_family->description, " (description score = ",
        $this_family->description_score, ")\n";
    my $simple_align = $this_family->get_SimpleAlign();
    my $alignIO = Bio::AlignIO->newFh(-format => "clustalw");
    print $alignIO $simple_align;
  }
}
