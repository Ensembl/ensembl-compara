#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use File::Basename;

my ($input,$subject_tag,$subject_fasta,$subject_index,$query_tag,$query_fasta,$query_index,$dir);

my $fastafetch_executable = "/nfs/acari/abel/bin/alpha-dec-osf4.0/fastafetch";

if (-e "/proc/version") {
  # it is a linux machine
  $fastafetch_executable = "/nfs/acari/abel/bin/i386/fastafetch";
}

my $FilterBlast_executable = "/nfs/acari/cara/src/ensembl_main/ensembl-compara/scripts/phusion/FilterBlast.pl";

my $blast_executable = "/usr/local/ensembl/bin/wublastn";

my $min_score = 300;
my $qy_input_only = 0;
my $p = "blastn";
my $FilterBlastArgs = "";
my $keeptmp = 0;

GetOptions('keeptmp' => \$keeptmp,
	   'FilterBlastArgs=s' => \$FilterBlastArgs,
	   'i=s' => \$input,
	   'st=s' => \$subject_tag,
	   'sf=s' => \$subject_fasta,
	   'si=s' => \$subject_index,
	   'qt=s' => \$query_tag,
	   'qf=s' => \$query_fasta,
	   'qi=s' => \$query_index,
	   'min_score=i' => \$min_score,
	   'dir=s' => \$dir,
	   'qy_input_only' => \$qy_input_only,
	   'p=s' => \$p);

my $rand = time().rand(1000);

if ($p eq "tblastx") {
  $blast_executable = "/usr/local/ensembl/bin/wutblastx";
} 

my $sb_file;
my @query_seq;

unless ($qy_input_only) {
  my $sb_id = "/tmp/sb_id.$rand";

  open S,">$sb_id";
  open F ,$input || die "can not open $input file\n";
  while (defined (my $line = <F>)) {
    if ($line =~ /^$subject_tag.*$/) {
      print S $line;
    }
    if ($line =~ /^$query_tag.*$/) {
      chomp $line;
      push @query_seq, $line;
    }
  }
  
  close F;
  close S;
  
  $sb_file = "/tmp/sb.$rand";
  unless (system("$fastafetch_executable $subject_fasta $subject_index $sb_id > $sb_file") == 0) {
    unlink glob("/tmp/*$rand*") unless ($keeptmp);
    die "error in fastafetch $sb_id, $!\n";
  }

  unless (system("pressdb $sb_file > /dev/null") == 0) {
    unlink glob("/tmp/*$rand*") unless ($keeptmp);
    die "error in pressdb, $!\n";
  }

} else {
  $sb_file = $subject_fasta;
  open F ,$input;
  while (defined (my $line = <F>)) {
    if ($line =~ /^$query_tag.*$/) {
      chomp $line;
      push @query_seq, $line;
    }
  }
  
  close F;
}

my $qy_file = "/tmp/qy.$rand";
my $blast_file = "/tmp/blast.$rand";
my $cigar_file = "/tmp/cigar.$rand";

foreach my $qy_seq (@query_seq) {

  unless(system("$fastafetch_executable $query_fasta $query_index $qy_seq > $qy_file") ==0) {
    unlink glob("/tmp/*$rand*") unless ($keeptmp);
    die "error in fastafetch $qy_seq, $!\n";
  } 
#  print STDERR "$qy_file, $sb_file, $blast_file\n";
  my $status = system("$blast_executable $sb_file $qy_file > $blast_file");
  unless ($status == 0 || $status == 4096 || $status == 4352 || $status == 5888) {

# 4096
# because wublastn produce a EXIT CODE 16 (16*256 = 4096). The reason is that the query
# sequence contains ONLY Ns, no seeding is possible.
# the message sent by wublastn is "There are no valid contexts in the requested search."

# 4352
# because wublastn produce a EXIT CODE 17 (23*256 = 4352). The reason is that the query 
# sequence is too short, no seeding is possible.
# the message sent by wublastn is " query sequence is shorter than the word length, W=11."

# 5888
# because wublastn produce a EXIT CODE 23 (23*256 = 5888). The reason is that the query 
# sequence contains MOSTLY Ns, no seeding is possible.
# the message sent by wublastn is "There are no valid contexts in the requested search."

    unlink glob("/tmp/*$rand*") unless ($keeptmp);
    die "error in wublast, $!\n";
  }
  my $cmd_line = "$FilterBlast_executable $FilterBlastArgs -p $p";
  unless (system("$cmd_line $subject_tag $min_score $blast_file >> $cigar_file") == 0) {
    unlink glob("/tmp/*$rand*") unless ($keeptmp);
    die "error in cigar, $!\n";
  }
}

my $final_file = $dir."/".basename($input).".cigar";
unless (system("cp $cigar_file $final_file") == 0) {
  unlink glob("/tmp/*$rand*") unless ($keeptmp);
  die "error in cp $cigar_file,$!\n";
}

unlink glob("/tmp/*$rand*") unless ($keeptmp);

exit 0;
