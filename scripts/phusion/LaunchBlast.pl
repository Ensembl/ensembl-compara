#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use File::Basename;

my ($input,$subject_tag,$subject_fasta,$subject_index,$query_tag,$query_fasta,$query_index,$dir);

my $fastafetch_executable = "/nfs/acari/abel/bin/fastafetch";
my $FilterBlast_executable = "/nfs/acari/abel/src/ensembl_main/ensembl-compara/scripts/phusion/FilterBlast.pl";
my $blast_executable = "/usr/local/ensembl/bin/wublastn";

my $min_score = 300;
my $qy_input_only = 0;
my $p = "blastn";

GetOptions('i=s' => \$input,
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
    unlink glob("/tmp/*$rand*");
    die "error in fastafetch $sb_id, $!\n";
  }

  unless (system("pressdb $sb_file > /dev/null") == 0) {
    unlink glob("/tmp/*$rand*");
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
    unlink glob("/tmp/*$rand*");
    die "error in fastafetch $qy_seq, $!\n";
  } 
  
  my $status = system("$blast_executable $sb_file $qy_file > $blast_file");
  unless ($status == 0 || $status == 4096 || $status == 5888) {

# 4096
# because wublastn produce a EXIT CODE 16 (16*256 = 4096). The reason is that the query
# sequence contains ONLY Ns, no seeding is possible.
# the message sent by wublastn is "There are no valid contexts in the requested search."

# 5888
# because wublastn produce a EXIT CODE 16 (23*256 = 4096). The reason is that the query 
# sequence contains MOSTLY Ns, no seeding is possible.
# the message sent by wublastn is "There are no valid contexts in the requested search."

    unlink glob("/tmp/*$rand*");
    die "error in wublast, $!\n";
  }
  unless (system("$FilterBlast_executable -p $p $subject_tag $min_score $blast_file >> $cigar_file") == 0) {
    unlink glob("/tmp/*$rand*");
    die "error in cigar, $!\n";
  }
}

my $final_file = $dir."/".basename($input).".cigar";
unless (system("cp $cigar_file $final_file") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in cp $cigar_file,$1\n";
}

unlink glob("/tmp/*$rand*");

exit 0;
