#!/usr/local/bin/perl -w

use strict;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::SeqIO;

$| = 1;

my $fragment_size = 500;
my $walk_step = 10000;

my $sb_host = 'ecs1a.sanger.ac.uk';
my $sb_dbname = 'human_live';
my $sb_dbuser = 'ensro';
my $sb_static_type = "NCBI_28";
my $sb_file_output = $sb_dbname."_raw_contigs";

my $qy_host = 'ecs1d.sanger.ac.uk';
my $qy_dbname = 'mus_musculus_core_1_3';
my $qy_dbuser = 'ensro';
my $qy_static_type = "CHR";
my $qy_file_output = $qy_dbname."_$fragment_size"."bp_fragment";

#my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $sb_host,
#					     -user => $sb_dbuser,
#					     -dbname => $sb_dbname);

#my $sth = $db->prepare("select distinct(c.id) from static_golden_path s,contig c where c.internal_id=s.raw_id and s.type=\"$sb_static_type\";");

#unless ($sth->execute()) {
#  $db->throw("Failed execution of a select query");
#}

#open OUT, ">$sb_file_output";

#my $totallength = 0;
#my $number_of_contigs = 0;

#while (my ($id) = $sth->fetchrow_array()) {
#  last;
#  print $id,"\n";
#  next;
#  my $contig = $db->get_Contig("$id");
#  $totallength += length($contig->seq);
#  $number_of_contigs++;
#  next;
#  my $maskedseq = $contig->get_repeatmasked_seq;
#  my $seqio = new Bio::SeqIO('-fh' => \*OUT,
#			     '-format' => 'fasta');
#  $seqio->write_seq($maskedseq);
#}

#print $totallength," bp ",$number_of_contigs," contigs\n";
#exit;
#close OUT;

my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $qy_host,
					  -user => $qy_dbuser,
					  -dbname => $qy_dbname);

my $sth = $db->prepare("select name,length from chromosome;");

unless ($sth->execute()) {
  $db->throw("Failed execution of a select query");
}

$db->static_golden_path_type($qy_static_type);
my $sgp = $db->get_StaticGoldenPathAdaptor;

open OUT, ">$qy_file_output";

while (my ($chr_name,$chr_length) = $sth->fetchrow_array()) {
#  next if ($chr_name ne "1");
#  print $chr_name," ",$chr_length,"\n";
#  my $count = 1;

  for (my $start = 1; $start < $chr_length; $start = $start + $walk_step) {
    my $end =  $start + $walk_step - 1;
    $end = $chr_length if ($end > $chr_length);

    my $vcontig = $sgp->fetch_VirtualContig_by_chr_start_end($chr_name,$start,$end);
    my $maskedseq = $vcontig->get_repeatmasked_seq;

    my @nonrepeat_fragments = split /[^ACGTacgt]+/, $maskedseq->seq;

    foreach my $fragment (@nonrepeat_fragments) {
      next if (length($fragment) < $fragment_size);
      my $pos = index($maskedseq->seq,$fragment);
#      $totallength += $fragment_size;
#      $number_of_contigs++;
#      print ">$chr_name.".($start + $pos).".".($start + $pos + $fragment_size - 1),"\n";
#      last;
      my $seqobj = new Bio::PrimarySeq (-seq => substr($fragment,0,$fragment_size),
    					-id  => "$chr_name.".($start + $pos).".".($start + $pos + $fragment_size - 1),
    					-moltype => 'dna');
      my $seqio = new Bio::SeqIO('-fh' => \*OUT,
    				 '-format' => 'fasta');
      $seqio->write_seq($seqobj);
      $start = $start + $pos + $fragment_size - 1;
      last;
    }
#    last if ($count == 100);
#    $count++;
  }
#  last;
}

#print $totallength," bp ",$number_of_contigs," contigs\n";

close OUT;

