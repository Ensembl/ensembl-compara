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

# get GenomeDB for human and mouse
my $humanGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("human");
my $mouseGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("mouse");

# get MethodLinkSpeciesSet for BLASTZ_NET alignments between human and mouse
my $method_link_species_set = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
     fetch_by_method_link_type_GenomeDBs("BLASTZ_NET", [$humanGDB, $mouseGDB]);

# get dnafrag for human chr 18
my $dnafrag = $comparaDBA->get_DnaFragAdaptor->
     fetch_by_GenomeDB_and_name($humanGDB, '18');

# get the alignments on a piece of the DnaFrag
my $genomic_align_blocks = $comparaDBA->get_GenomicAlignBlockAdaptor->
     fetch_all_by_MethodLinkSpeciesSet_DnaFrag($method_link_species_set, $dnafrag, 75550000, 75560000);
foreach my $this_genomic_align_block (@{$genomic_align_blocks}) {
  print "Bio::EnsEMBL::Compara::GenomicAlignBlock #", $this_genomic_align_block->dbID, "\n";
  print "=====================================================\n";
  print " length: ", $this_genomic_align_block->length, "; score: ", $this_genomic_align_block->score, "\n";
  my $all_genomic_aligns = $this_genomic_align_block->get_all_GenomicAligns();
  foreach my $this_genomic_align (@$all_genomic_aligns) {
    print "  - ",
      join(":",
          $this_genomic_align->dnafrag->genome_db->name,
          $this_genomic_align->dnafrag->coord_system_name,
          $this_genomic_align->dnafrag->name,
          $this_genomic_align->dnafrag_start,
          $this_genomic_align->dnafrag_end,
          $this_genomic_align->dnafrag_strand),
      "\n",
      $this_genomic_align->aligned_sequence, "\n\n";
  }
}

exit(0);

