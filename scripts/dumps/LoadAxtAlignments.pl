#!/usr/local/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Tools::Block;
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::AlignBlockSet;
use Bio::EnsEMBL::Compara::DnaFrag;
use Getopt::Long;

my $usage = "\nUsage: $0 [options] axtFile|STDIN

 Insert into a compara database axt alignments

Options:

 -reference_species   Name of the reference species (e.g. Homo_sapiens)
 -query_species       Name of the query species (e.g. Mus_musculus)
 -compara_host        host for compara database
 -compara_dbname      compara database name
 -compara_dbuser      username for connection to \"compara_dbname\"
 -compara_pass        passwd for connection to \"compara_dbname\"
\n";


my $help = 0;
my $compara_host;
my $compara_dbname;
my $compara_dbuser;
my $compara_pass;

my $reference_species;
my $query_species;
my $min_score;

&GetOptions('h' => \$help,
	    'compara_host=s' => \$compara_host,
	    'compara_dbname=s' => \$compara_dbname,
	    'compara_dbuser=s' => \$compara_dbuser,
	    'compara_pass=s' => \$compara_pass,
	    'reference_species=s' => \$reference_species,
	    'query_species=s' => \$query_species,
	    'min_score=i' => \$min_score);

if ($help) {
  print $usage;
  exit 0;
}

unless (defined $compara_host ||
	defined $compara_dbname ||
	defined $compara_dbuser ||
	defined $compara_pass ||
	defined $reference_species ||
	defined $query_species) {
  print "
!!! IMPORTANT : All following parameters should be defined !!!
  compara_host
  compara_dbname
  compara_dbuser
  compara_pass
  reference_species
  query_species
";
  print $usage;
  exit 0;
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor ('-host' => $compara_host,
						      '-user' => $compara_dbuser,
						      '-dbname' => $compara_dbname,
						      '-pass' => $compara_pass);

my $gdbadp = $db->get_GenomeDBAdaptor;
my $sb_species_dbadaptor = $gdbadp->fetch_by_species_tag($reference_species)->db_adaptor;
my $sb_chradp = $sb_species_dbadaptor->get_ChromosomeAdaptor;
my $sb_chrs = $sb_chradp->fetch_all;
my %sb_chrs;

foreach my $sb_chr (@{$sb_chrs}) {
  $sb_chrs{$sb_chr->chr_name} = $sb_chr;
}

my $qy_species_dbadaptor = $gdbadp->fetch_by_species_tag($query_species)->db_adaptor;
my $qy_chradp = $qy_species_dbadaptor->get_ChromosomeAdaptor;
my $qy_chrs = $qy_chradp->fetch_all;
my %qy_chrs;

foreach my $qy_chr (@{$qy_chrs}) {
  $qy_chrs{$qy_chr->chr_name} = $qy_chr;
}

my ($ref_chr,$ref_start,$ref_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score);
my ($ref_seq,$qy_seq);
my @DnaDnaAlignFeatures;

print STDERR "Readind axt alignments...";
while (defined (my $line =<>)) {

  if ($line =~ /^\d+\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+([\+\-])\s+(\-?\d+)$/) {
    ($ref_chr,$ref_start,$ref_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score) = ($1,$2,$3,$4,$5,$6,$7,$8);
#    if ($ref_start == 12709535 && $ref_end == 12709545) {
#      print STDERR "$ref_chr,$ref_start,$ref_end,$qy_chr,$qy_start,$qy_end,$qy_strand,$score\n";
#    }
    
    if ($score < $min_score) {
#      print $line;
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
      $qy_start = $qy_chrs{$qy_chr}->length - $qy_end + 1;
      $qy_end = $qy_start + $length;
    }
  }

  if ($line =~ /^[acgtnACGTN-]+$/ && defined $ref_seq) {
    chomp $line;
    $qy_seq = $line;
  } elsif ($line =~ /^[acgtnACGTN-]+$/) {
    chomp $line;
    $ref_seq = $line;
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

@DnaDnaAlignFeatures = sort {$a->seqname cmp $b->seqname ||
			       $a->hseqname cmp $b->hseqname} @DnaDnaAlignFeatures;

my $aln = new Bio::EnsEMBL::Compara::GenomicAlign;
my $abs = new Bio::EnsEMBL::Compara::AlignBlockSet;
my $current_align_row_id = 1;
my $hseqname;
my $ref_dnafrag;
my $qy_dnafrag;

my $galn = $db->get_GenomicAlignAdaptor;
my $align_id;

print STDERR "Preparing data for storage...";
#print STDERR scalar @DnaDnaAlignFeatures,"\n";
foreach my $f (@DnaDnaAlignFeatures) {
#  if ($f->start == 12709535 && $f->end == 12709545) {
#    print STDERR $f->seqname," ",$f->start," ",$f->end," ",$f->hseqname," ",$f->hstart," ",$f->hend," ",$f->hstrand," ",$f->percent_id," ",$f->cigar_string,"\n";
#  }
  unless (defined $hseqname) {
    $hseqname = $f->hseqname;
    $align_id = $galn->fetch_align_id_by_align_name($f->seqname);
  }
  unless (defined $ref_dnafrag && defined $qy_dnafrag) {
    $ref_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
    $ref_dnafrag->name($f->seqname);
    $ref_dnafrag->genomedb($gdbadp->fetch_by_species_tag($reference_species));
    $ref_dnafrag->type("Chromosome");
    $qy_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
    $qy_dnafrag->name($f->hseqname);
    $qy_dnafrag->genomedb($gdbadp->fetch_by_species_tag($query_species));
    $qy_dnafrag->type("Chromosome");
    
  }
  if ($hseqname ne $f->hseqname) {
    $aln->add_AlignBlockSet($current_align_row_id,$abs);
    $abs = new Bio::EnsEMBL::Compara::AlignBlockSet;
    $hseqname = $f->hseqname;
    $qy_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
    $qy_dnafrag->name($f->hseqname);
    $qy_dnafrag->genomedb($gdbadp->fetch_by_species_tag($query_species));
    $qy_dnafrag->type("Chromosome");
    $align_id = $galn->fetch_align_id_by_align_name($f->seqname);
    $current_align_row_id++;
  }

  my $ab = new Bio::EnsEMBL::Compara::AlignBlock;
  
  $ab->align_start($f->start);
  $ab->align_end($f->end);
  $ab->start($f->hstart);
  $ab->end($f->hend);
  if ($f->strand == 1) {
    $ab->strand($f->hstrand);
  } elsif ($f->strand == -1) {
    $ab->strand(- $f->hstrand);
  }
  $ab->score($f->score);
  $ab->perc_id($f->percent_id);
  # think here to revert cigar_string if strand==-1 !!

  my $cigar_string = $f->cigar_string;
  $cigar_string =~ s/I/x/g;
  $cigar_string =~ s/D/I/g;
  $cigar_string =~ s/x/D/g;

  $ab->cigar_string($cigar_string);
  $ab->dnafrag($qy_dnafrag);
  
  $abs->add_AlignBlock($ab);

  $ab = new Bio::EnsEMBL::Compara::AlignBlock;
  
  $ab->align_start($f->start);
  $ab->align_end($f->end);
  $ab->start($f->start);
  $ab->end($f->end);
  $ab->strand(1);
  $ab->score($f->score);
  $ab->perc_id($f->percent_id);
  # think here to revert cigar_string if strand==-1 !!
  $ab->cigar_string($f->cigar_string);
  $ab->dnafrag($ref_dnafrag);
  
  $abs->add_AlignBlock($ab);
}

$aln->add_AlignBlockSet($current_align_row_id,$abs);

print STDERR "Done\n";

#exit;
print STDERR "Storing data...";

$galn->store($aln,$align_id);

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
