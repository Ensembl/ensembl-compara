#!/usr/local/bin/perl -w

use strict;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::SeqIO;
use Getopt::Long;

my $frag;

&GetOptions('frag=s' => \$frag);

$| = 1;

my $fragment_size = 1000;
my $walk_step = 5000;

my $sb_host = 'ecs1b.sanger.ac.uk';
my $sb_dbname = 'human_live2';
my $sb_dbuser = 'ensro';
my $sb_static_type = "NCBI_28";
my $sb_file_output = $sb_dbname."_golden_raw_contigs_type_".$sb_static_type;
my $sb_already_dumped_file = $sb_file_output.".dumped";
my %sb_already_dumped;

my $qy_host = 'ecs1f.sanger.ac.uk';
my $qy_dbname = 'mouse_Sanger_Nov01_denormalised';
my $qy_dbuser = 'ensro';
my $qy_static_type = "CHR";

unless (defined $frag) {

  my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $sb_host,
					       -user => $sb_dbuser,
					       -dbname => $sb_dbname);
  
  my $sth = $db->prepare("select distinct(c.id) from static_golden_path s,contig c where c.internal_id=s.raw_id and s.type=\"$sb_static_type\" and chr_name not like \"%NT%\";");
  
  unless ($sth->execute()) {
    $db->throw("Failed execution of a select query");
  }
  
  if (-e $sb_already_dumped_file) {
    open F,$sb_already_dumped_file || die "Could not open $sb_already_dumped_file; $!\n";
    while (defined (my $line = <F>)) {
      if ($line =~ /^(\S+)$/) {
	my $id = $1;
	$sb_already_dumped{$id} = 1;
      }
    }
    close F;
  }
  
  open OUT, ">$sb_file_output" || die "Could not open $sb_file_output; $!\n";
  open F,">>$sb_already_dumped_file" || die "Could not open $sb_already_dumped_file; $!\n";
  
  while (my ($id) = $sth->fetchrow_array()) {
    next if (defined $sb_already_dumped{$id});
    my $contig = $db->get_Contig("$id");
    my $maskedseq = $contig->get_repeatmasked_seq;
    my $seqio = new Bio::SeqIO('-fh' => \*OUT,
			       '-format' => 'fasta');
    $seqio->write_seq($maskedseq);
    print F "$id\n";
    $sb_already_dumped{$id} = 1;
  }
  
  close F;
  close OUT;
  
} else {
  my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $qy_host,
					       -user => $qy_dbuser,
					       -dbname => $qy_dbname);
  
  my $sth = $db->prepare("select max(chr_end) from static_golden_path where chr_name=\"$frag\" and type=\"$qy_static_type\"");
#  my $sth = $db->prepare("select name,length from chromosome;");
  
  unless ($sth->execute()) {
    $db->throw("Failed execution of a select query");
  }
  
  $db->static_golden_path_type($qy_static_type);
  my $sgp = $db->get_StaticGoldenPathAdaptor;
  
  my $qy_file_output = $qy_dbname."_$fragment_size"."bp_$walk_step"."_fragment_$frag";
  open OUT, ">$qy_file_output";
  
#  while (my ($chr_name,$chr_length) = $sth->fetchrow_array()) {
  while (my ($chr_length) = $sth->fetchrow_array()) {
#    next if ($chr_name ne $frag);
    my $chr_name = $frag;
#    print $chr_name," ",$chr_length,"\n";
#    my $count = 1;
    
    my $vcontig = $sgp->fetch_VirtualContig_by_chr_name($chr_name);
    print STDERR "Getting the repeat-masked sequence of chromosome $chr_name...\n";
    my $maskedseq = $vcontig->get_repeatmasked_seq;
#    my $maskedseq = $vcontig->seq;
    print STDERR "...sequence loaded.\n";

    for (my $start = 0; $start < $chr_length; $start = $start + $walk_step) {
#      my $end =  $start + $walk_step - 1;
#      $end = $chr_length if ($end > $chr_length);
      
      my $seq = substr($maskedseq->seq,$start,$walk_step);
      my @nonrepeat_fragments = split /[^ACGTacgt]+/, $seq;
      
      foreach my $fragment (@nonrepeat_fragments) {
	next if (length($fragment) < $fragment_size);
	my $pos = index($seq,$fragment);
#	$totallength += $fragment_size;
#	$number_of_contigs++;
#	print ">$chr_name.".($start + $pos + 1).".".($start + $pos + $fragment_size),"\n";
#	last;
	my $seqobj = new Bio::PrimarySeq (-seq => substr($fragment,0,$fragment_size),
					  -id  => "$chr_name.".($start + $pos + 1).".".($start + $pos + $fragment_size),
					  -moltype => 'dna');
	my $seqio = new Bio::SeqIO('-fh' => \*OUT,
				   '-format' => 'fasta');
	$seqio->write_seq($seqobj);
	$start = $start + $pos + $fragment_size - 1;
	last;
      }
#      last if ($count == 100);
#      $count++;
    }
#    last;
  }
  close OUT;
}
