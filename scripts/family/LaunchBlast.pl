#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use File::Basename;

my ($idqy,$fastadb,$fastaindex,$dir);

my $blast_executable = "/usr/local/ensembl/bin/blastall"; 
my $fastafetch_executable = "/nfs/acari/abel/bin/alpha-dec-osf4.0/fastafetch";

if (-e "/proc/version") {
  # it is a linux machine
  $fastafetch_executable = "/nfs/acari/abel/bin/i386/fastafetch";
}

print STDERR "fastafetch_executable: ",$fastafetch_executable,"\n";

my $blast_parser_executable = "/nfs/acari/abel/bin/mcxdeblast";
my $tab_file;

GetOptions('idqy=s' => \$idqy,
	   'fastadb=s' => \$fastadb,
	   'fastaindex=s' => \$fastaindex,
	   'tab=s' => \$tab_file,
	   'dir=s' => \$dir);

unless (-e $idqy) {
  die "$idqy does not exist\n";
}

my $rand = time().rand(1000);

my $qy_file = "/tmp/qy.$rand";
my $blast_file = "/tmp/blast.$rand";
my $raw_file = "/tmp/raw.$rand";

unless(system("$fastafetch_executable $fastadb $fastaindex $idqy > $qy_file") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in $fastafetch_executable, $!\n";
} 

my $status = system("$blast_executable -d $fastadb -i $qy_file -p blastp -e 0.00001 -v 250 -b 0 > $blast_file");
unless ($status == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in $blast_executable, $!\n";
}

unless (system("$blast_parser_executable --score=e --sort=a --ecut=0 --tab=$tab_file --stdhandler $blast_file > $raw_file") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in $blast_parser_executable, $!\n";
}

my $final_raw_file = $dir."/".basename($idqy).".raw";
unless (system("gzip -c $raw_file > $final_raw_file.gz") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in cp $raw_file, $!\n";
}

unlink glob("/tmp/*$rand*");

exit 0;
