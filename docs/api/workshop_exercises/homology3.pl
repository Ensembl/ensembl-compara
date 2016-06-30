use strict;
use warnings;

use Bio::EnsEMBL::Registry;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the compara member adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get the compara homology adaptor
my $homology_adaptor = $reg->get_adaptor("Multi", "compara", "Homology");

## The BioPerl alignment formatter
my $alignIO = Bio::AlignIO->newFh(-format => "clustalw");

foreach my $mouse_stable_id (qw(ENSMUSG00000004843 ENSMUSG00000025746)) {

  ## Get the compara member
  my $gene_member = $gene_member_adaptor->fetch_by_stable_id($mouse_stable_id);

  ## Get all the orthologues in human
  my $all_homologies = $homology_adaptor->fetch_all_by_Member($gene_member, -TARGET_SPECIES => 'human', -METHOD_LINK_TYPE => 'ENSEMBL_ORTHOLOGUES');

  ## For each homology
  foreach my $this_homology (@{$all_homologies}) {

    ## Get the alignments
    my $aa_align = $this_homology->get_SimpleAlign();
    my $nt_align = $this_homology->get_SimpleAlign(-SEQ_TYPE => 'cds');

    ## Print the summary of the homology
    print $this_homology->toString(), "\n";
    printf("Alignments have %.2f%% identity at the protein-level and %.2f%% at the nucleotide level.\n", $aa_align->average_percentage_identity(), $nt_align->average_percentage_identity());
    print "The non-synonymous substitution rate is: ", $this_homology->dn(), "\n";
    print "The synonymous substitution rate is: ", $this_homology->ds(), "\n";
    print "The ratio is: ", $this_homology->dnds_ratio(), "\n";

    ## Print the alignments
    print $alignIO $aa_align;
    print $alignIO $nt_align;
  }
  print "\n";
}

