#!/usr/local/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Tools::Block;
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;
use Getopt::Long;

my $usage = "\nUsage: $0 [options] axtFile|STDIN

 Insert into a compara database axt alignments

Options:

 -reference_species   Name of the reference species (e.g. Homo_sapiens)
 -query_species       Name of the query species (e.g. Mus_musculus)
 -host        host for compara database
 -dbname      compara database name
 -dbuser      username for connection to \"compara_dbname\"
 -pass        passwd for connection to \"compara_dbname\"
\n";


my $help = 0;
my $host = "ecs1b.internal.sanger.ac.uk";
my $dbname = "ensembl_compara_tight_12_1";
my $dbuser = "ensadmin";
my $pass = "ensembl";

my $reference_species;
my $query_species;
my $min_score = 0;
my $conf_file = "/nfs/acari/abel/src/ensembl_main/ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf";

&GetOptions('h' => \$help,
	    'host=s' => \$host,
	    'dbname=s' => \$dbname,
	    'dbuser=s' => \$dbuser,
	    'pass=s' => \$pass,
	    'reference_species=s' => \$reference_species,
	    'query_species=s' => \$query_species,
	    'min_score=i' => \$min_score);

if ($help) {
  print $usage;
  exit 0;
}

#unless (defined $host ||
#	defined $dbname ||
#	defined $dbuser ||
#	defined $pass ||
#	defined $reference_species ||
#	defined $query_species) {
#  print "
#!!! IMPORTANT : All following parameters should be defined !!!
#  host
#  dbname
#  dbuser
#  pass
#  reference_species
#  query_species
#";
#  print $usage;
#  exit 0;
#}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor ('-conf_file' => $conf_file,
						      '-host' => $host,
						      '-user' => $dbuser,
						      '-dbname' => $dbname,
						      '-pass' => $pass);

my $gdb_adaptor = $db->get_GenomeDBAdaptor;
my $cs_genome_db_id = 7;
my $cs_genome_db = $gdb_adaptor->fetch_by_dbID($cs_genome_db_id);
my $qy_genome_db_id = 8;
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

my ($axt_number,$ref_chr,$ref_start,$ref_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score);
my ($ref_seq,$qy_seq);
my @DnaDnaAlignFeatures;

print STDERR "Readind axt alignments...";
while (defined (my $line =<>)) {
  
  if ($line =~ /^(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+([\+\-])\s+(\-?\d+)$/) {
    ($axt_number,$ref_chr,$ref_start,$ref_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score) = ($1,$2,$3,$4,$5,$6,$7,$8,$9);

    if ($score < $min_score) {
     
      while (defined (my $line =<>)) {
	if ($line =~ /^\d+\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+([\+\-])\s+(\-?\d+)$/) {
	  ($ref_chr,$ref_start,$ref_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score) = ($1,$2,$3,$4,$5,$6,$7,$8);
	  last;
	}
      }
    }
    if ($qy_strand eq "+") {
      $qy_strand = 1;
    }
    if ($qy_strand eq "-") {
      $qy_strand = -1;
      my $length = $qy_end - $qy_start;
      $qy_start = $qy_chromosomes{$qy_chr}->length - $qy_end + 1;
      $qy_end = $qy_start + $length;
    }
  }

  if ($line =~ /^[a-zA-Z-]+$/ && defined $ref_seq) {
    chomp $line;
    $qy_seq = $line;
    unless ($qy_seq =~ /^[acgtnACGTN-]+$/) {
      warn "qy_seq not acgtn only in axt_number $axt_number\n";
    }
  } elsif ($line =~ /^[a-zA-Z-]+$/) {
    chomp $line;
    $ref_seq = $line;
    unless ($ref_seq =~ /^[acgtnACGTN-]+$/) {
      warn "ref_seq not acgtn only in axt_number $axt_number\n";
    }
    
  }

  if ($line =~ /^$/) {
    
    my $identity = identity($ref_seq,$qy_seq);
    
    my @ungapped_features;    
    my $block = new Bio::EnsEMBL::Pipeline::Tools::Block;
    $block->score($score);
    $block->identity($identity);
    $block->qstart($ref_start);
    $block->qend($ref_end);
    $block->qstrand(1);
    $block->qlength(length($ref_seq));
    $block->sstart($qy_start);
    $block->send($qy_end);
    $block->sstrand($qy_strand);
    $block->slength(length($qy_seq));
    $block->qseq($ref_seq);
    $block->sseq($qy_seq);

    while (my $ungapped_block = $block->nextUngappedBlock("blastn")) {
      my ($qstart,$qend,$qstrand,$sstart,$send,$sstrand,$score,$perc_id) = ($ungapped_block->qstart,$ungapped_block->qend,$ungapped_block->qstrand,$ungapped_block->sstart,$ungapped_block->send,$ungapped_block->sstrand,$ungapped_block->score,$ungapped_block->identity);
      
      my $fp = new Bio::EnsEMBL::FeaturePair;
      
      $fp->start($qstart);
      $fp->end($qend);
      $fp->strand($qstrand);
      $fp->seqname($ref_chr);
      
      $fp->hstart($sstart);
      $fp->hend($send);
      $fp->hstrand($sstrand);
      $fp->hseqname($qy_chr);
      
      $fp->score($score);
      $fp->percent_id($perc_id);
      
      push @ungapped_features, $fp;
    }
    my $DnaDnaAlignFeature = new Bio::EnsEMBL::DnaDnaAlignFeature('-features' => \@ungapped_features);
    
    push @DnaDnaAlignFeatures,$DnaDnaAlignFeature ;
    
    undef $ref_seq;
    undef $qy_seq;
  }
}

print STDERR "Done\n";

print STDERR "Preparing data for storage...";
print STDERR scalar @DnaDnaAlignFeatures,"\n";
foreach my $f (@DnaDnaAlignFeatures) {
  my ($cs_chr,$cs_start,$cs_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score,$percid,$cigar) = ($f->seqname,$f->start,$f->end,$f->hseqname,$f->hstart,$f->hend,$f->hstrand,$f->score,$f->percent_id,$f->cigar_string);
  
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
  $genomic_align->cigar_line($cigar);

  $galn_adaptor->store([$genomic_align]);

  # think here to revert cigar_string if strand==-1 !!

}

print STDERR "Done\n";

sub identity {
  my ($ref_seq,$qy_seq) = @_;
  
  my $length = length($ref_seq);
  
  unless (length($qy_seq) == $length) {
    warn "reference sequence length ($length bp) and query sequence length (".length($qy_seq)." bp) should be identical
exit 1\n";
    exit 1;
  }
  
  my @ref_seq_array = split //, $ref_seq;
  my @qy_seq_array = split //, $qy_seq;
  my $number_identity = 0;

  for (my $i=0;$i<$length;$i++) {
    if (lc $ref_seq_array[$i] eq lc $qy_seq_array[$i]) {
      $number_identity++;
    }
  }
  return int($number_identity/$length*100);
}
