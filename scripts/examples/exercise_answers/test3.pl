#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $reg_conf = shift;
die("must specify registry conf file on commandline\n") unless($reg_conf);
Bio::EnsEMBL::Registry->load_all($reg_conf);

# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry->get_DBAdaptor('compara', 'compara');
my $memberDBA = Bio::EnsEMBL::Registry->get_adaptor('compara', 'compara', 'Member');
my $genomeDBA = Bio::EnsEMBL::Registry->get_adaptor('compara', 'compara', 'GenomeDB');

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

exit(0);

