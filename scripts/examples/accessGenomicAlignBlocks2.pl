#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::SimpleAlign;

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
      "\n";
  }
  print_simple_align($this_genomic_align_block->get_SimpleAlign, 80);

}

exit(0);


sub print_simple_align
{
  my $alignment = shift;
  my $aaPerLine = shift;
  $aaPerLine=40 unless($aaPerLine and $aaPerLine > 0);

  my ($seq1, $seq2)  = $alignment->each_seq;
  my $seqStr1 = "|".$seq1->seq().'|';
  my $seqStr2 = "|".$seq2->seq().'|';

  my $enddiff = length($seqStr1) - length($seqStr2);
  while($enddiff>0) { $seqStr2 .= " "; $enddiff--; }
  while($enddiff<0) { $seqStr1 .= " "; $enddiff++; }

  my $label1 = sprintf("%10s : ", $seq1->id);
  my $label2 = sprintf("%10s : ", "");
  my $label3 = sprintf("%10s : ", $seq2->id);

  my $line2 = "";
  for(my $x=0; $x<length($seqStr1); $x++) {
    if(substr($seqStr1,$x,1) eq substr($seqStr2, $x,1)) { $line2.='|'; } else { $line2.=' '; }
  }

  my $offset=0;
  my $numLines = (length($seqStr1) / $aaPerLine);
  while($numLines>0) {
    printf("$label1 %s\n", substr($seqStr1,$offset,$aaPerLine));
    printf("$label2 %s\n", substr($line2,$offset,$aaPerLine));
    printf("$label3 %s\n", substr($seqStr2,$offset,$aaPerLine));
    print("\n\n");
    $offset+=$aaPerLine;
    $numLines--;
  }
}

1;
