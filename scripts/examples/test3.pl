#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script fetches all the alignments with the rat of the
# DNA segment containing the given human gene
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


# get compara DBAdaptor
my $comparaDBA = $reg->get_DBAdaptor('compara', 'compara');
my $memberDBA = $comparaDBA->get_MemberAdaptor();
my $genomeDBA = $comparaDBA->get_GenomeDBAdaptor();

# get GenomeDB for human and mouse
my $humanGDB = $genomeDBA->fetch_by_registry_name("human");
my $ratGDB = $genomeDBA->fetch_by_registry_name("rat");

my $method_link_species_set = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
     fetch_by_method_link_type_GenomeDBs("BLASTZ_NET", [$humanGDB, $ratGDB]);

my $gene = $memberDBA->fetch_by_source_stable_id('ENSEMBLGENE', 'ENSG00000153347');
$gene->print_member;

my $dnafrag = $comparaDBA->get_DnaFragAdaptor->
     fetch_by_GenomeDB_and_name($humanGDB, $gene->chr_name);

# get the alignments on a piece of the DnaFrag
my $genomic_align_blocks = $comparaDBA->get_GenomicAlignBlockAdaptor->
     fetch_all_by_MethodLinkSpeciesSet_DnaFrag($method_link_species_set, $dnafrag, $gene->chr_start, $gene->chr_end);
foreach my $this_genomic_align_block (@{$genomic_align_blocks}) {
  my $all_genomic_aligns = $this_genomic_align_block->get_all_GenomicAligns();
  foreach my $this_genomic_align (@$all_genomic_aligns) {
    next unless($this_genomic_align->dnafrag->genome_db->dbID == $ratGDB->dbID);
    print "  - ", 
      join(":",
          $this_genomic_align->dnafrag->name,
          $this_genomic_align->dnafrag_start,
          $this_genomic_align->dnafrag_end,
          $this_genomic_align->dnafrag_strand,
          $this_genomic_align_block->score), 
      "\n";
  }
}

