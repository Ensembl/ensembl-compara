#!/usr/local/ensembl/bin/perl -w

$| = 1;

use strict;
use Bio::EnsEMBL::Pipeline::Runnable::Blat;
#use Bio::EnsEMBL::GenePair::DBSQL::PairAdaptor;
#use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::SeqIO;
use Getopt::Long;
#use diagnostics;

my $idqy;
my $indexqy;
my $fastaqy;
my $fastadb;
my $dbname;
my $query_type="dna";
my $target_type="dna";
my $Nooc_file;
my @Qseqs;

my $fastafetch_executable = "/nfs/acari/abel/bin/alpha-dec-osf4.0/fastafetch";

if (-e "/proc/version") {
  # it is a linux machine
    $fastafetch_executable = "/nfs/acari/abel/bin/i386/fastafetch";
    }
    
GetOptions( 'idqy=s'   => \$idqy,
    	    'fastaqy=s' => \$fastaqy,
	    'indexqy=s' => \$indexqy,
	    'fastadb=s' => \$fastadb,
	    'dbname=s'   => \$dbname,
	    'query_type:s'=>\$query_type,
	    'target_type:s'=>\$target_type,
	    'makefile:s'  => \$Nooc_file);
	    
unless (-e $idqy) {
	 die "$idqy file does not exist\n";
	 }
	 
	 
######
#check for the Nocc file and if it dosn't exist make it	
#
#usage:
#   blat database query [-ooc=11.ooc] output.psl
#
#options: -t=dnax -q=dnax -ooc=5.ooc -tileSize=5 -makeOoc=5.ooc -mask=lower -qMask=lower -out=wublast 
 
	 
	      
 						

my $rand = time().rand(1000);

my $qy_file = "/tmp/qy.$rand";

# might be good to use /usr/local/ensembl/bin/fetchdb instead of fastafetch

unless(system("$fastafetch_executable $fastaqy $indexqy $idqy > $qy_file") ==0) {
  unlink glob("/tmp/*$rand*");
  die "error in fastafetch $idqy, $!\n";
  } 
  
print "$Nooc_file\n";

	 	my $seqio = new Bio::SeqIO(-file => $qy_file,
	                            -format => 'fasta');
				    
 		my $number_seq_treated = 0;
 
  		while (my $seq = $seqio->next_seq) {
  			push @Qseqs, $seq;
			}
unless (-e $Nooc_file){#Fetch seqs and make makefile
print "making make file\n";

	my $runnable = new Bio::EnsEMBL::Pipeline::Runnable::Blat(-query_seqs        => \@Qseqs,
	 							-database       => $fastadb,
								-query_type	=> $query_type,
								-target_type	=> $target_type,
								-options         => "-ooc=$Nooc_file -tileSize=5 -makeOoc=$Nooc_file -mask=lower -qMask=lower ");
	$runnable->run;
	
#Run with querys
	 $runnable = new Bio::EnsEMBL::Pipeline::Runnable::Blat(-query_seqs        => \@Qseqs,
	 							-database       => $fastadb,
								-query_type	=> $query_type,
								-parse		=> 1,
								-target_type	=> $target_type,
								-options         => "-ooc=$Nooc_file -mask=lower -qMask=lower ");
	$runnable->run;
	
	#my @top_hsps = $runnable->output;
#foreach my $out (@top_hsps){




#	print STDERR $out->seqname."\t".$out->analysis->program."\tsimilarity\t".$out->start."\t".$out->end."\t".$out->hseqname."\t".$out->hstart."\t".$out->hend."\t".
#                      $out->score."\t".$out->p_value."\t".$out->hstrand."\t". $out->strand."\t".$out->identical_matches."\t".$out->positive_matches."\t".$out->cigar_string."\n"; #this line is the start of a gff line for display
	#}

	#$db->store_blat($runnable->output);
	
	
	}
else{ #run blat using the Nooc file	 
	
	my $runnable = new Bio::EnsEMBL::Pipeline::Runnable::Blat(-query_seqs        => \@Qseqs,
	 							-database       => $fastadb,
								-query_type	=> $query_type,
								-target_type	=> $target_type,
								-parse		=> 1,
								-options         => "-ooc=$Nooc_file -mask=lower -qMask=lower ");
	$runnable->run;
	
	my @top_hsps = $runnable->output;
	
#foreach my $out (@top_hsps){
#	foreach my $subF($out->sub_SeqFeature){#featurepairs --hopefully
#	print STDERR $subF->seqname."\t".$subF->analysis->program."\tsimilarity\t".$subF->start."\t".$subF->end."\t".$subF->hseqname."\t".$subF->hstart."\t".$subF->hend."\t".
#                     $subF->score."\t".$subF->p_value."\t".$subF->hstrand."\t". $subF->strand."\t".$subF->identical_matches."\t".$subF->positive_matches."\t".$subF->cigar_string."\n"; #this line is the start of a gff line for display
		
		
		
		
		#use Load AxtAlignments from dumps
		#}
		#}
	

	#$db->store_blat($runnable->output);
	
 	
 		
}   	
 unlink glob("/tmp/*$rand*");  
   
   
   
   
