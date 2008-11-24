#!/usr/local/bin/perl
use warnings;
use strict;

use Bio::EnsEMBL::Registry;
my $reg = "Bio::EnsEMBL::Registry";

$reg->load_registry_from_db
  ( -host => 'ensembldb.ensembl.org',
    -user => 'anonymous');

my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");
my $member_adaptor = $reg->get_adaptor("Multi", "compara", "Member");
my $protein_tree_adaptor = $reg->get_adaptor("Multi", "compara", "ProteinTree");

my $interpro_domain = "IPR002305";

## Get all the human Genes with that interpro domain
my $human_genes = $human_gene_adaptor->fetch_all_by_domain($interpro_domain);

## Loop through all the genes. Although we know the gene, we need to get the actual
## protein to get the coordinates of the domain. Also, we only want the proteins
## for the longest translation for each gene as these are the one used for building
## the gene trees
foreach my $this_human_gene (@$human_genes) {
  print "GENE: ", $this_human_gene->stable_id, " - ", $this_human_gene->external_name, "\n";
  ## Get the gene_member for this human gene
  my $gene_member = $member_adaptor->fetch_by_source_stable_id(
      "ENSEMBLGENE", $this_human_gene->stable_id);
  ## Get the longest peptide Member, i.e. the one used for building the trees
  my $peptide_member = $gene_member->get_longest_peptide_Member;

  # Go through all the possible transcripts
  foreach my $this_transcript (@{$this_human_gene->get_all_Transcripts}) {
    my $translation = $this_transcript->translation;
    # Skip if no translation (i.e. pseudogene)
    next if (!$translation);
    # Skip if not the longest protein
    next if ($translation->stable_id ne $peptide_member->stable_id);
    # Find the coordinates of this feature on the protein (start and end coord.)
    foreach my $domain_feature (@{$translation->get_all_DomainFeatures}) {
      next if ($domain_feature->interpro_ac ne $interpro_domain);
      my ($start, $end) = ($domain_feature->start, $domain_feature->end);
      ## Note: these feature do not have a strand (well, strand is 0).
      get_interpro_alignment($peptide_member, $start, $end);
    }
  }
  print "\n";
}

sub get_interpro_alignment {
  my ($peptide_member, $start, $end) = @_;

  ## Trim the tree and leave only proteins of interest (human, mouse, rat, dog, fruitfly)
  my $protein_tree = $protein_tree_adaptor->fetch_by_Member_root_id($peptide_member);
  foreach my $this_leaf (@{$protein_tree->get_all_leaves}) {
    if ($this_leaf->genome_db->name ne "Homo sapiens" and
        $this_leaf->genome_db->name ne "Mus musculus" and
        $this_leaf->genome_db->name ne "Rattus norvegicus" and
        $this_leaf->genome_db->name ne "Canis familiaris" and
        $this_leaf->genome_db->name ne "Drosophila melanogaster") {
      ## This unlinks the leave
      $this_leaf->disavow_parent();
      ## This simplifies the tree (removes resulting nodes with 1 child only)
      $protein_tree = $protein_tree->minimize_tree();
    }
  }
  $protein_tree->print_tree(50);

  # Find out the start and end coordinates of the domain on the alignment.
  my ($aln_start, $aln_length);
  foreach my $this_leaf (@{$protein_tree->get_all_leaves}) {
    # Coordinates refer to the query peptide only, skip if this leaf corresponds to another peptide
    next if ($this_leaf->stable_id ne $peptide_member->stable_id);
    my $alignment = $this_leaf->alignment_string;
    my $length = $end - $start + 1;
    ## OK, this is a complex RegEx. Mainly the idea is to capture the bit of the aligned
    ## sequence that accounts for the first START nucleotides and the bit of the aligned
    ## sequence that accounts for the following LENGTH nucleotides. Here is a step-by-step
    ## explanation:
    ## 1. (?:\-*\w\-*) where (?:....) means clustering, not capturing. This means one
    ##     nucleotide with whatever number of gaps before or after
    ## 2. (?:\-*\w\-*){$start} This means $start nucleotides with whatever number of
    ##     gaps before, after or in-between
    ## 3. ((?:\-*\w\-*){$start}) Capture $start nucleotides with whatever number of
    ##     gaps before, after or in-between
    ## 4. ((?:\-*\w\-*){$start}) The same for $length
    my ($pre, $this) = $alignment =~ /((?:\-*\w\-*){$start})((?:\-*\w\-*){$length})/;
    ## Now we have in $pre as many numcleotides as defined by $start and whatever number
    ## of gaps. The InterPro domains starts just after this $pre and lasts until the end
    ## of $this. Save the lengths of these regions and exit the loop:
    $aln_start = length($pre);
    $aln_length = length($this);
    last;
  }

  ## Use the start and end coordinates of the domain on the alignment to trim the alignment:
  foreach my $this_leaf (@{$protein_tree->get_all_leaves}) {
    my $alignment = $this_leaf->alignment_string;
    print ">", $this_leaf->gene_member->stable_id, "\n";
    print substr($alignment, $aln_start, $aln_length), "\n";
  }
}
