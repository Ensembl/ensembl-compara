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

$0 -host ecs2d.internal.sanger.ac.uk -dbuser ensadmin -dbpass xxxx -dbname ensembl_compara_12_1 \
-conf_file /nfs/acari/abel/src/ensembl_main/ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf
-alignment_type WGA_HCR -cs_genome_db_id 1 -qy_genome_db_id 2

Options:

 -host        host for compara database
 -dbname      compara database name
 -dbuser      username for connection to \"compara_dbname\"
 -pass        passwd for connection to \"compara_dbname\"
 -cs_genome_db_id   genome_db_id of the consensus species (e.g. 1 for Homo_sapiens)
 -qy_genome_db_id   genome_db_id of the query species (e.g. 2 for Mus_musculus)
 -alignment_type type of alignment stored e.g. WGA (default: WGA_HCR) 
 -confi_file compara conf file
 -min_score 300
\n";


my $help = 0;

my ($host, $dbname, $dbuser, $pass);
my ($cs_genome_db_id, $qy_genome_db_id,$conf_file);

my $min_score = 0;
my $alignment_type = 'WGA_HCR';

GetOptions('h' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'pass=s' => \$pass,
	   'cs_genome_db_id=s' => \$cs_genome_db_id,
	   'qy_genome_db_id=s' => \$qy_genome_db_id,
	   'alignment_type=s' => \$alignment_type,
	   'min_score=i' => \$min_score,
	   'conf_file=s' => \$conf_file);

if ($help) {
  print $usage;
  exit 0;
}

unless (defined $host &&
	defined $dbname &&
	defined $dbuser &&
	defined $pass &&
	defined $cs_genome_db_id &&
	defined $qy_genome_db_id &&
	defined $conf_file) {
  print "
!!! IMPORTANT : All following parameters should be defined !!!
  host
  dbname
  dbuser
  pass
  cs_genome_db_id 
  qy_genome_db_id
  conf_file
  
";
  print $usage;
  exit 0;
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor ('-conf_file' => $conf_file,
						      '-host' => $host,
						      '-user' => $dbuser,
						      '-dbname' => $dbname,
						      '-pass' => $pass);

my $stored_max_alignment_length;
my $values = $db->get_MetaContainer->list_value_by_key("max_alignment_length");

if(@$values) {
  $stored_max_alignment_length = $values->[0];
}

my $gdb_adaptor = $db->get_GenomeDBAdaptor;
my $cs_genome_db = $gdb_adaptor->fetch_by_dbID($cs_genome_db_id);
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
# Updating method_link_species if needed (maybe put that in GenomicAlignAdaptor store method)

my $sth_method_link = $db->prepare("SELECT method_link_id FROM method_link WHERE type = ?");
$sth_method_link->execute($alignment_type);
my ($method_link_id) = $sth_method_link->fetchrow_array();

unless (defined $method_link_id) {
  warn "There is no type $alignment_type in the method_link table of compara db.
EXIT 1";
  exit 1;
}

my $sth_method_link_species = $db->prepare("
SELECT ml.method_link_id
FROM method_link_species mls1, method_link_species mls2, method_link ml
WHERE mls1.method_link_id = ml.method_link_id AND
      mls2.method_link_id = ml.method_link_id AND
      mls1.genome_db_id = ? AND
      mls2.genome_db_id = ? AND
      mls1.species_set = mls2.species_set AND
      ml.method_link_id = ?");

$sth_method_link_species->execute($cs_genome_db_id,$qy_genome_db_id,$method_link_id);
my ($already_stored) = $sth_method_link_species->fetchrow_array();

unless (defined $already_stored) {
  $sth_method_link_species = $db->prepare("SELECT max(species_set) FROM method_link_species where method_link_id = ?");
  $sth_method_link_species->execute($method_link_id);
  my ($max_species_set) = $sth_method_link_species->fetchrow_array();

  $max_species_set = 0 unless (defined $max_species_set);

  $sth_method_link_species = $db->prepare("INSERT INTO method_link_species (method_link_id,species_set,genome_db_id) VALUES (?,?,?)");
  $sth_method_link_species->execute($method_link_id,$max_species_set + 1,$cs_genome_db_id);
  $sth_method_link_species->execute($method_link_id,$max_species_set + 1,$qy_genome_db_id);
}


# Updating genomic_align_genome if needed (maybe put that in GenomicAlignAdaptor store method)
my $sth_genomic_align_genome = $db->prepare("SELECT method_link_id FROM genomic_align_genome WHERE consensus_genome_db_id = ? AND query_genome_db_id = ? AND method_link_id = ?");
$sth_genomic_align_genome->execute($cs_genome_db_id,$qy_genome_db_id,$method_link_id);
($already_stored) = $sth_genomic_align_genome->fetchrow_array();

unless (defined $already_stored) {
  $sth_genomic_align_genome = $db->prepare("INSERT INTO genomic_align_genome (consensus_genome_db_id,query_genome_db_id,method_link_id) VALUES (?,?,?)");
  $sth_genomic_align_genome->execute($cs_genome_db_id,$qy_genome_db_id,$method_link_id);
}

my $max_alignment_length = 0;

my ($axt_number,$ref_chr,$ref_start,$ref_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score);
my ($ref_seq,$qy_seq);
my @DnaDnaAlignFeatures;
my %repeated_alignment;

print STDERR "Reading axt alignments in progress...\n";
while (my $line =<>) {
  
  if ($line =~ /^(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+([\+\-])\s+(\-?\d+)$/) {
    ($axt_number,$ref_chr,$ref_start,$ref_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score) = ($1,$2,$3,$4,$5,$6,$7,$8,$9);

    if ($score < $min_score) {
      while ($line =<>) {
	if ($line =~ /^\d+\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+([\+\-])\s+(\-?\d+)$/) {
	  ($ref_chr,$ref_start,$ref_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score) = ($1,$2,$3,$4,$5,$6,$7,$8);
	  last;
	}
      }
    }
    if (defined $repeated_alignment{$ref_chr."_".$ref_start."_".$ref_end."_".$qy_chr."_".$qy_start."_".$qy_end}) {
      print STDERR "Repeated alignment: $line";
      while ($line =<>) {
	last if ($line =~ /^$/);
      }
      next;
    }
    $repeated_alignment{$ref_chr."_".$ref_start."_".$ref_end."_".$qy_chr."_".$qy_start."_".$qy_end} = 1;
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

print STDERR "Reading axt alignments done\n";

print STDERR "Preparing data for storage for ". scalar @DnaDnaAlignFeatures . " features...\n";
foreach my $f (@DnaDnaAlignFeatures) {
  my ($cs_chr,$cs_start,$cs_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score,$percid,$cigar) = ($f->seqname,$f->start,$f->end,$f->hseqname,$f->hstart,$f->hend,$f->hstrand,$f->score,$f->percent_id,$f->cigar_string);

  my $cs_max_alignment_length = $cs_end - $cs_start + 1;
  $max_alignment_length = $cs_max_alignment_length if ($max_alignment_length < $cs_max_alignment_length);  
  my $qy_max_alignment_length = $qy_end - $qy_start + 1;
  $max_alignment_length = $qy_max_alignment_length if ($max_alignment_length < $qy_max_alignment_length);

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
  $genomic_align->alignment_type($alignment_type);
  $genomic_align->score($score);
  $percid = 0 unless (defined $percid);
  $genomic_align->perc_id($percid);
  $genomic_align->cigar_line($cigar);

  $galn_adaptor->store([$genomic_align]);

  # think here to revert cigar_string if strand==-1 !!

}

if (! defined $stored_max_alignment_length) {
  $db->get_MetaContainer->store_key_value("max_alignment_length",$max_alignment_length + 1);
} elsif ($stored_max_alignment_length < $max_alignment_length + 1) {
  $db->get_MetaContainer->update_key_value("max_alignment_length",$max_alignment_length + 1);
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
