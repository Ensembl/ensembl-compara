#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::GenomicAlign;

my $conf_file = "/nfs/acari/abel/src/ensembl_main/ensembl-compara/scripts/PhusionBlast/Compara.conf";

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-conf_file => $conf_file,
						     -host => "ecs2d.internal.sanger.ac.uk",
						     -dbname => "ensembl_compara_11_1",
						     -user => "ecs2dadmin",
						     -pass => "TyhRv");

my $gdb_adaptor = $db->get_GenomeDBAdaptor;
my $cs_genome_db_id = 1;
my $cs_genome_db = $gdb_adaptor->fetch_by_dbID($cs_genome_db_id);
my $qy_tag = "Mm";
my $qy_genome_db_id = 2;
my $qy_genome_db= $gdb_adaptor->fetch_by_dbID($qy_genome_db_id);

my @genomicaligns;

my $dnafrag_adaptor = $db->get_DnaFragAdaptor;
my $galn_adaptor = $db->get_GenomicAlignAdaptor;

my $cs_dbadaptor= $db->get_db_adaptor($cs_genome_db->name,$cs_genome_db->assembly);
my @cs_chromosomes = @{$cs_dbadaptor->get_ChromosomeAdaptor->fetch_all};
my %cs_chromosomes;

foreach my $chr (@cs_chromosomes) {
  $cs_chromosomes{$chr->chr_name} = $chr;
}

my $qy_dbadaptor= $db->get_db_adaptor($qy_genome_db->name,$qy_genome_db->assembly);
my @qy_chromosomes = @{$qy_dbadaptor->get_ChromosomeAdaptor->fetch_all};
my %qy_chromosomes;

foreach my $chr (@qy_chromosomes) {
  $qy_chromosomes{$chr->chr_name} = $chr;
}

while (defined (my $line = <>) ) {
  chomp $line;
  my ($d1,$query_coords,$d3,$d4,$cs_chr,$cs_start,$cs_end,$qy_strand,$d9,$score,$percid,$cigar) = split /\t/,$line;
  my ($qy_chr,$qy_start,$qy_end);
  if ($query_coords =~ /^$qy_tag(\S+)\.(\d+):(\d+)-(\d+)$/) {
    ($qy_chr,$qy_start,$qy_end) = ($1,$2+$3-1,$2+$4-1);
  }
  if ($qy_strand eq "+") {
    $qy_strand = 1;
  } elsif ($qy_strand eq "-") {
    $qy_strand = -1;
  }
  
  my $cs_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
  $cs_dnafrag->name($cs_chr);
  $cs_dnafrag->genomedb($cs_genome_db);
  $cs_dnafrag->type("Chromosome");
  $cs_dnafrag->start(1);
  $cs_dnafrag->end($cs_chromosomes{$cs_chr}->length);
  $dnafrag_adaptor->store_if_needed($cs_dnafrag);

  my $qy_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
  $qy_dnafrag->name($qy_chr);
  $qy_dnafrag->genomedb($qy_genome_db);
  $qy_dnafrag->type("Chromosome");
  $qy_dnafrag->start(1);
  $qy_dnafrag->end($qy_chromosomes{$qy_chr}->length);
  $dnafrag_adaptor->store_if_needed($qy_dnafrag);
  
  my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign;
  $genomic_align->consensus_dnafrag($cs_dnafrag);
  $genomic_align->consensus_start($cs_start);
  $genomic_align->consensus_end($cs_end);
  $genomic_align->query_dnafrag($qy_dnafrag);
  $genomic_align->query_start($qy_start);
  $genomic_align->query_end($qy_end);
  $genomic_align->query_strand($qy_strand);
  $genomic_align->score($score);
  $percid = 0 unless (defined $percid);
  $genomic_align->perc_id($percid);

  if (defined $cigar) {
    $cigar =~ s/D/X/g;
    $cigar =~ s/I/D/g;
    $cigar =~ s/X/I/g;
  } else {
    $cigar = "";
  }
  $genomic_align->cigar_line($cigar);

  $galn_adaptor->store([$genomic_align]);
}



