#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Pipeline::Runnable::Blastz;
use Bio::SeqIO;
use Getopt::Long;

my $idqy;
my $fastaqy;
my $indexqy;
my $database;
my @featurepairs;
my $options='T=2 H=2200';
my $fastafetch_executable = "/nfs/acari/abel/bin/alpha-dec-osf4.0/fastafetch";

if (-e "/proc/version") {
  # it is a linux machine
    $fastafetch_executable = "/nfs/acari/abel/bin/i386/fastafetch";
    }

GetOptions( 'idqy=s'   => \$idqy,
    	    'fastaqy=s' => \$fastaqy,
	    'indexqy=s' => \$indexqy,
	    'fastadb=s' => \$database,
	    'options=s' => \$options);
unless (-e $idqy) {
	 die "$idqy file does not exist\n";
	 }

my $rand = time().rand(1000);

my $qy_file = "/tmp/qybz.$rand";

unless(system("$fastafetch_executable $fastaqy $indexqy $idqy > $qy_file") ==0) {
  unlink glob("/tmp/*$rand*");
  die "error in fastafetch $idqy, $!\n";
  } 
  



  my $seqio = new Bio::SeqIO(-file   => $qy_file,
                           -format => 'fasta');
  while (my $seq = $seqio->next_seq) {


  my $blastz =  new Bio::EnsEMBL::Pipeline::Runnable::Blastz ('-query' => $seq,
     '-database'  => $database,
     '-options'   => '$options');

  $blastz->run();

  @featurepairs = $blastz->output();

  foreach my $fp (@featurepairs) {
      print STDOUT $fp->seqname."\t".$fp->start."\t".$fp->end."\t".$fp->hseqname."\t".$fp->hstart."\t".$fp->hend."\t".$fp->hstrand."\t".$fp->score."\t".$fp->percent_id."\t".$fp->cigar_string."\n";
  }
}
  unlink glob("/tmp/*$rand*");

