#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::AlignIO;

my $reg_conf = shift;
die("must specify registry conf file on commandline\n") unless($reg_conf);
Bio::EnsEMBL::Registry->load_all($reg_conf);

# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry->get_DBAdaptor('compara', 'compara');

# get GenomeDB for human and mouse
my $humanGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("human");
my $human_gdb_id = $humanGDB->dbID;

my $mouseGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("mouse");
my $mouse_gdb_id = $mouseGDB->dbID;

# get MethodLinkSpeciesSet for BLASTZ_NET alignments between human and mouse
my $blastz_mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
     fetch_by_method_link_type_GenomeDBs("BLASTZ_NET", [$humanGDB, $mouseGDB]);

my $homology_mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
    fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES',[$human_gdb_id,$mouse_gdb_id]);

my $homology_list = $comparaDBA->get_HomologyAdaptor->
    fetch_all_by_MethodLinkSpeciesSet($homology_mlss);

# set up an AlignIO to format SimpleAlign output
my $alignIO = Bio::AlignIO->newFh(-interleaved=>1, -fh=>\*STDOUT, -format=>'psi', -idlength=>20);


foreach my $homology (@{$homology_list}) {
  $homology->print_homology;

  my $mem_attribs = $homology->get_all_Member_Attribute;
  my $mouse_gene = undef;
  foreach my $member_attribute (@{$mem_attribs}) {
    my ($member, $atrb) = @{$member_attribute};
    if($member->genome_db_id == $mouse_gdb_id) { $mouse_gene = $member; }
  }
  next unless($mouse_gene);
  
  my $dnafrag = $comparaDBA->get_DnaFragAdaptor->
     fetch_by_GenomeDB_and_name($mouseGDB, $mouse_gene->chr_name);
  unless($dnafrag) { print("oops no dnafrag\n"); next; }

  # get the alignments on a piece of the DnaFrag
  my $genomic_align_blocks = $comparaDBA->get_GenomicAlignBlockAdaptor->
       fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
           $blastz_mlss, 
           $dnafrag, 
           $mouse_gene->chr_start, $mouse_gene->chr_end);

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

    print $alignIO $this_genomic_align_block->get_SimpleAlign;
  }
  last;
}

exit(0);

