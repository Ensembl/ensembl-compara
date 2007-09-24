#!/usr/local/ensembl/bin/perl -w


=head1 NAME

LaunchBLAT.pl

=head1 DESCRIPTION

This script launches a BLAT comparison

=head1 SYNOPSIS

perl LaunchBLAT_pipeline.pl
 -fastadb database.fa
 -target_type dnax
 -fastaqy query.fa
 -target_type dnax

perl LaunchBLAT_pipeline.pl
 -fastadb database.fa
 -target_type dnax
 -idqy ids.txt
 -indexqy query_index.txt
 -fastafetch fastafetch.pl

=head1 ARGUMENTS

=head2 TARGET SEQUENCE

=over

=item B<-fastadb fasta_file>

File name of the target sequence (FASTA format)

=item B<-target_type type>

Type of sequence: dna, prot, dnax
    
=item B<-Nooc Nooc_file>

File containing overused N-mers. If none is specified, a temporary file will be used.
    
=back

=head2 QUERY SEQUENCE

=over

There are two ways of specifying the query sequence. The first one
is based on a single FASTA file while the second one is based on an
index file and a file containing the list of IDs to be extracted
using the index file. In the second case, a specific fastafetch
program can be specified.

=item B<-fastaqy fasta_file>

File name of the query sequence (FASTA format)

=item B<-idqy ids_file>

File containing the IDs to be used (one per line)

=item B<-indexqy index_file>

File indexing the IDs

=item B<-fastafetch fastafetch_exe>

Program used to fetch the sequences in the ids_file using the index_file

=item B<-query_type type>

Type of sequence: dna, rna, prot, dnax, rnax
    
=back

=head1 AUTHORS

 Cara Woodwark (cara@ebi.ac.uk)
 Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2004, 2005. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This script is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk


=cut

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
my $query_type="dnax";
my $target_type="dnax";
my $Nooc_file = "/tmp/Nooc.$$";
my $min_score = 30;

my $fastafetch_executable = "/nfs/acari/abel/bin/alpha-dec-osf4.0/fastafetch";

if (-e "/proc/version") {
  # it is a linux machine
    $fastafetch_executable = "/nfs/acari/abel/bin/i386/fastafetch";
    }
    
GetOptions( 'idqy=s'   => \$idqy,
	    'indexqy=s' => \$indexqy,
 	    'fastaqy=s' => \$fastaqy,
	    'fastadb=s' => \$fastadb,
	    'dbname=s'   => \$dbname,
	    'query_type:s'=>\$query_type,
	    'target_type:s'=>\$target_type,
	    'makefile:s'  => \$Nooc_file,
	    'Nooc:s'  => \$Nooc_file,
	    'min_score=i'  => \$min_score,
	    'fastafetch=s'  => \$fastafetch_executable);
	    
if (!defined($fastaqy) and !(defined($idqy) and defined($indexqy))) {
  die "No query sequences have been defined. Use either -fastaqy or ".
    "both -idqy and -indexqy\n";
}
	 
	 
######
#check for the Nocc file and if it doesn't exist make it	
#
#usage:
#   blat database query [-ooc=11.ooc] output.psl
#
#options: -t=dnax -q=dnax -ooc=5.ooc -tileSize=5 -makeOoc=5.ooc -mask=lower -qMask=lower -out=wublast 
 
	 
	      
 						

my $rand = time().rand(1000);

if (!defined($fastaqy)) {
  $fastaqy = "/tmp/qy.$rand";

  # might be good to use /usr/local/ensembl/bin/fetchdb instead of fastafetch

  unless(system("$fastafetch_executable $indexqy $idqy > $fastaqy") ==0) {
    unlink glob("/tmp/*$rand*");
    die "error in fastafetch $idqy, $!\n$fastafetch_executable $indexqy $idqy > $fastaqy";
  }
}

print "$Nooc_file\n";

unless (-e $Nooc_file){#Fetch seqs and make makefile
print "making make file\n";

	my $runnable = new Bio::EnsEMBL::Pipeline::Runnable::Blat(
                -blat         => "blat-32",
                -query_file   => $fastaqy,
	 							-database     => $fastadb,
								-query_type	  => $query_type,
								-target_type	=> $target_type,
								-options      => "-ooc=$Nooc_file -tileSize=11 -makeOoc=$Nooc_file -mask=lower -qMask=lower ");
	$runnable->run;
	
#Run with queries
  $runnable = new Bio::EnsEMBL::Pipeline::Runnable::Blat(
                -blat         => "blat-32",
                -query_file   => $fastaqy,
	 							-database     => $fastadb,
								-query_type	  => $query_type,
								-parse		    => 1,
								-target_type	=> $target_type,
								-options      => "-ooc=$Nooc_file -mask=lower -qMask=lower -minScore=$min_score");
  $runnable->run;
  unlink($Nooc_file) if ($Nooc_file =~ /^\/tmp/);
	
	#my @top_hsps = $runnable->output;
#foreach my $out (@top_hsps){




#	print STDERR $out->seqname."\t".$out->analysis->program."\tsimilarity\t".$out->start."\t".$out->end."\t".$out->hseqname."\t".$out->hstart."\t".$out->hend."\t".
#                      $out->score."\t".$out->p_value."\t".$out->hstrand."\t". $out->strand."\t".$out->identical_matches."\t".$out->positive_matches."\t".$out->cigar_string."\n"; #this line is the start of a gff line for display
	#}

	#$db->store_blat($runnable->output);
	
	
	}
else{ #run blat using the Nooc file	 
	
	my $runnable = new Bio::EnsEMBL::Pipeline::Runnable::Blat(
                -blat         => "blat-32",
                -query_file   => $fastaqy,
	 							-database     => $fastadb,
								-query_type	  => $query_type,
								-target_type	=> $target_type,
								-parse		    => 1,
								-options      => "-ooc=$Nooc_file -mask=lower -qMask=lower -minScore=$min_score");
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
   
   
   
   
