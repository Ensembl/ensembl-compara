#!/usr/local/bin/perl -w

BEGIN {
    require "Bio/EnsEMBL/Compara/ComparaConf.pl";
    # Can we have a way of reading a (local) ComparaConf.pl as well?
    # e.g. if it exists in the current dir, use that one in preference
}

use strict;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::SeqIO;
use Getopt::Long;

my $qy_chr_name;

GetOptions('qy_chr_name=s' => \$qy_chr_name);

$| = 1;

#Get and set general options
my %conf =  %::ComparaConf;

my $sb_host = $conf{'sb_host'};
my $sb_dbname = $conf{'sb_dbname'};
my $sb_dbuser = $conf{'sb_dbuser'};
my $sb_static_type = $conf{'sb_static_type'};
my $sb_file_output = $sb_dbname."_".$sb_static_type;
my $sb_already_dumped_file = $sb_file_output.".dumped";
my %sb_already_dumped;
my $sb_fragment_type = $conf{'sb_fragment_type'};
my $sb_fragment_size = $conf{'sb_fragment_size'};
my $sb_chr_name_restriction = $conf{'sb_chr_name_restriction'};

my $qy_host = $conf{'qy_host'};
my $qy_dbname = $conf{'qy_dbname'};
my $qy_dbuser = $conf{'qy_dbuser'};
my $qy_static_type = $conf{'qy_static_type'};
my $qy_fragment_size = $conf{'qy_fragment_size'};
my $qy_walk_step = $conf{'qy_walk_step'};

unless (defined $qy_chr_name) {

  my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $sb_host,
					       -user => $sb_dbuser,
					       -dbname => $sb_dbname);
  
  my $sth = $db->prepare("select chr_name,max(chr_end) from static_golden_path where type= ? and chr_name not like ? group by chr_name;");
  
  unless ($sth->execute($sb_static_type,$sb_chr_name_restriction)) {
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
  
  open OUT, ">>$sb_file_output" || die "Could not open $sb_file_output; $!\n";
  open F,">>$sb_already_dumped_file" || die "Could not open $sb_already_dumped_file; $!\n";

  while (my ($chr_name,$length) = $sth->fetchrow_array()) {
#    next if ($chr_name ne "Y");
    if ($sb_fragment_type eq "vc") {
      for (my $start=1;$start<=$length;$start+=$sb_fragment_size) {
	my $end = $start+$sb_fragment_size-1;
	$end = $length if ($end > $length);
	my $id = $chr_name.".".$start.".".$end;
	next if (defined $sb_already_dumped{$id});
	my $contig = $db->get_StaticGoldenPathAdaptor->fetch_VirtualContig_by_chr_start_end("$chr_name",$start,$end);
	my $maskedseq = $contig->get_repeatmasked_seq;
	$maskedseq->id($id);
	my $seqio = new Bio::SeqIO('-fh' => \*OUT,
				   '-format' => 'fasta');
	$seqio->write_seq($maskedseq);
	print F "$id\n";
	$sb_already_dumped{$id} = 1;
      }
    } elsif ($sb_fragment_type eq "raw") {
      my $sth = $db->prepare("select distinct(c.id) from static_golden_path s,contig c where s.raw_id=c.internal_id and s.type= ? and s.chr_name=?;");
      
      unless ($sth->execute($sb_static_type,$chr_name)) {
	$db->throw("Failed execution of a select query");
      }

      while (my $id = ($sth->fetchrow_array())) {
	next if (defined $sb_already_dumped{$id});
	my $contig = $db->get_Contig($id);
	my $maskedseq = $contig->get_repeatmasked_seq;
	my $seqio = new Bio::SeqIO('-fh' => \*OUT,
				   '-format' => 'fasta');
	$seqio->write_seq($maskedseq);
	print F "$id\n";
	$sb_already_dumped{$id} = 1;
      }
    }
  }
  
  close F;
  close OUT;
  
} else {
  my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $qy_host,
					       -user => $qy_dbuser,
					       -dbname => $qy_dbname);
  
  my $sth = $db->prepare("select max(chr_end) from static_golden_path where chr_name= ? and type= ?");
  
  unless ($sth->execute($qy_chr_name,$qy_static_type)) {
    $db->throw("Failed execution of a select query");
  }
  
  $db->static_golden_path_type($qy_static_type);
  my $sgp = $db->get_StaticGoldenPathAdaptor;
  
  my $qy_file_output = $qy_dbname."_$qy_fragment_size"."bp_$qy_walk_step"."_fragment_$qy_chr_name";
  open OUT, ">$qy_file_output";
  
  while (my ($chr_length) = $sth->fetchrow_array()) {
    
    my $vcontig = $sgp->fetch_VirtualContig_by_chr_name($qy_chr_name);
    print STDERR "Getting the repeat-masked sequence of chromosome $qy_chr_name...\n";
    my $maskedseq = $vcontig->get_repeatmasked_seq;
    print STDERR "...sequence loaded.\n";

    for (my $start = 0; $start < $chr_length; $start = $start + $qy_walk_step) {
      
      my $seq = substr($maskedseq->seq,$start,$qy_walk_step);
      my @nonrepeat_fragments = split /[^ACGTacgt]+/, $seq;
      
      foreach my $fragment (@nonrepeat_fragments) {
	next if (length($fragment) < $qy_fragment_size);
	my $pos = index($seq,$fragment);
	my $seqobj = new Bio::PrimarySeq (-seq => substr($fragment,0,$qy_fragment_size),
					  -id  => "$qy_chr_name.".($start + $pos + 1).".".($start + $pos + $qy_fragment_size),
					  -moltype => 'dna');
	my $seqio = new Bio::SeqIO('-fh' => \*OUT,
				   '-format' => 'fasta');
	$seqio->write_seq($seqobj);
	$start = $start + $pos + $qy_fragment_size - 1;
	last;
      }
    }
  }
  close OUT;
}
