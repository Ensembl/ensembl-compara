use strict;
use warnings;

use Bio::EnsEMBL::Registry;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the human gene adaptor
my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

## Get the compara genemember adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get all existing gene object with the name FRAS1
my $these_genes = $human_gene_adaptor->fetch_all_by_external_name('FRAS1');

## For each of these genes
foreach my $this_gene (@{$these_genes}) {

  print $this_gene->source(), " ", $this_gene->stable_id(), ": ", $this_gene->description(), "\n";

  ## Get the compara member
  my $gene_member = $gene_member_adaptor->fetch_by_stable_id($this_gene->stable_id());

  ## Print some info for this member
  print $gene_member->toString(), "\n";

  ## Get all the protein member for this gene member
  my $protein_members = $gene_member->get_all_SeqMembers();
  foreach my $this_protein_member (@{$protein_members}) {

    ## Print some info for this protein member
    print $this_protein_member->toString(), "   ";

    ## Print its sequence
    print $this_protein_member->sequence(), "\n";

  }
}
