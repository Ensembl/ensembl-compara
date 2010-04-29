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

my $homology_mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
    fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES',[$human_gdb_id,$mouse_gdb_id]);

my $homology_list = $comparaDBA->get_HomologyAdaptor->
    fetch_all_by_MethodLinkSpeciesSet($homology_mlss);
printf("fetched %d homologies\n", scalar(@$homology_list));

# set up an AlignIO to format SimpleAlign output
my $alignIO = Bio::AlignIO->newFh(-interleaved=>1, -fh=>\*STDOUT, -format=>'psi', -idlength=>20);


my $count=0;
foreach my $homology (@{$homology_list}) {
  $count++;
  $homology->print_homology;
  
  my $mem_attribs = $homology->get_all_Member_Attribute;
  my $human_gene = undef;
  my $mouse_gene = undef;
  foreach my $member_attribute (@{$mem_attribs}) {
    my ($member, $atrb) = @{$member_attribute};
    if($member->genome_db_id == $mouse_gdb_id) { $mouse_gene = $member; }
    if($member->genome_db_id == $human_gdb_id) { $human_gene = $member; }
  }
  next unless($mouse_gene and $human_gene);
  $mouse_gene->print_member;
  $human_gene->print_member;

  # get the alignments on a piece of the DnaFrag
  printf("fetch_all_by_species_region(%s,%s,%s,%s,%d,%d,%s)\n", 
			      $mouse_gene->genome_db->name,
			      $mouse_gene->genome_db->assembly,
                              $human_gene->genome_db->name,
			      $human_gene->genome_db->assembly,
			      $mouse_gene->chr_name,
			      $mouse_gene->chr_start,
			      $mouse_gene->chr_end,
			      'BLASTZ_NET');
  

  my $dnafeatures = $comparaDBA->get_DnaAlignFeatureAdaptor->fetch_all_by_species_region(
			      $mouse_gene->genome_db->name,
			      $mouse_gene->genome_db->assembly,
                              $human_gene->genome_db->name,
			      $human_gene->genome_db->assembly,
			      $mouse_gene->chr_name,
			      $mouse_gene->chr_start,
			      $mouse_gene->chr_end,
			      'BLASTZ_NET');
  
  foreach my $ddaf (@{$dnafeatures}) {
    next unless(($mouse_gene->chr_name eq $ddaf->seqname) and ($human_gene->chr_name eq $ddaf->hseqname));
    print "=====================================================\n";
    printf(" length: %d; score: %d\n", $ddaf->alignment_length, $ddaf->score);
    printf("  - %s: %s : %d : %d : %d\n", $ddaf->species, $ddaf->seqname, $ddaf->start, $ddaf->end, $ddaf->strand);
    printf("  - %s : %s : %d : %d : %d\n", $ddaf->hspecies, $ddaf->hseqname, $ddaf->hstart, $ddaf->hend, $ddaf->hstrand);
    print $alignIO $ddaf->get_SimpleAlign;
  }
  last if($count > 10);
}

exit(0);

