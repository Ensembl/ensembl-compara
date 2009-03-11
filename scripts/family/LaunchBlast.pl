#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use File::Basename;

my ($idqy,$fastadb,$fastaindex,$dir);

#my $blast_executable = "/software/bin/blastall"; 
my $blast_executable = "/usr/local/ensembl/bin/blastall";

# There is a new version of fastafetch on the farm, /usr/local/ensembl/bin/fastafetch
# We had problem previously with it, as sometimes the fasta files we use have IUPAC letter
# that fastafetch was not aware of. If any problem with fall back to the compiled version in
# /nfs/acari/avilella/bin/alpha-dec-osf4.0 or /nfs/acari/avilella/bin/i386/ and inform Guy Slater to fix
# the potential bug

my $fastafetch_executable = "/usr/local/ensembl/bin/fastafetch";
my $blast_parser_executable = "/nfs/acari/avilella/bin/mcxdeblast";
my $tab_file;

GetOptions(
       'idqy=s'       => \$idqy,
	   'fastadb=s'    => \$fastadb,
	   'fastaindex=s' => \$fastaindex,
	   'tab=s'        => \$tab_file,
	   'dir=s'        => \$dir,
       'baexec=s'     => \$blast_executable,
       'ffexec=s'     => \$fastafetch_executable,
       'bpexec=s'     => \$blast_parser_executable,
       );

my $final_raw_file = $dir."/".basename($idqy).".raw";

unless (-e $idqy) {
  die "$idqy does not exist\n";
}

my $rand = time().rand(1000);

my $qy_file = "/tmp/qy.$rand";
my $blast_file = "/tmp/blast.$rand";
my $raw_file = "/tmp/raw.$rand";

# We should get the sequence directly from the compara database.

if (-e "$final_raw_file.gz") {
  print STDERR "Job already finished. Exit.\n";
  exit 0;
}

unless(system("$fastafetch_executable -F true $fastadb $fastaindex $idqy |grep -v \"^Message\" > $qy_file") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in $fastafetch_executable, $!\n";
} 

my $status = system("$blast_executable -d $fastadb -i $qy_file -p blastp -e 0.00001 -v 250 -b 0 > $blast_file");
unless ($status == 0) {
  $DB::single=1;1;#??
  unlink glob("/tmp/*$rand*");
  die "error in $blast_executable, $!\n";
}

unless (system("$blast_parser_executable --score=e --sort=a --ecut=0 --tab=$tab_file $blast_file > $raw_file") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in $blast_parser_executable, $!\n";
}

unless (system("gzip -c $raw_file > $final_raw_file.gz") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in cp $raw_file, $!\n";
}

unlink glob("/tmp/*$rand*");

exit 0;
