#!/usr/bin/perl -w

$| = 1;

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBSQL::AnalysisAdaptor;
use Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPep;
use Bio::EnsEMBL::DnaDnaAlignFeature;

#use Bio::EnsEMBL::GenePair::DBSQL::PairAdaptor;

my ($help, $host, $user, $pass, $dbname, $port, $compara_conf, $adaptor);
my $member_id;
my $logic_name;
my $verbose=1;


GetOptions('help' => \$help,
           'host=s' => \$host,
           'user=s' => \$user,
           'pass=s' => \$pass,
           'dbname=s' => \$dbname,
	   'port=i' => \$port,
           'compara=s' => \$compara_conf,
	   'member_id=s' => \$member_id,
	   'logic_name=s' => \$logic_name,
	   'verbose!'    => \$verbose,
	  );
if ($help) { usage(); }

if(-e $compara_conf) {
  my %conf = %{do $compara_conf};

  $host = $conf{host} if($conf{host});
  $port = $conf{port} if($conf{port});
  $user = $conf{user} if($conf{user});
  $pass = $conf{pass} if($conf{pass});
  $dbname = $conf{dbname} if($conf{dbname});
  $adaptor = $conf{adaptor} if($conf{adaptor});
}

unless(defined($host) and defined($user) and defined($dbname)) {
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage(); 
}

unless (defined($member_id) and defined($logic_name)) {
  print "\nERROR : must specify a member.member_id and analysis.logic_name\n\n";
  usage();
}


my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => $host,
						     -user => $user,
						     -pass => $pass,
						     -dbname => $dbname);

testBlastRunnable($db, "/scratch/jessica/FastaPeptideFiles/ENSMUSP00000027035.fasta",
                  "/scratch/jessica/FastaPeptideFiles/Rattus_norvegicus_RGSC3.1.fasta");

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "LaunchBlastRunnable.pl -pass {-compara | -host -user -dbname} -stable_id -logic_name [options]\n";
  print "  -help                  : print this help\n";
  print "  -compara <conf file>   : read compara DB connection info from config file <path>\n";
  print "                           which is perl hash file with keys 'host' 'port' 'user' 'dbname'\n";
  print "  -host <machine>        : set <machine> as location of compara DB\n";
  print "  -port <port#>          : use <port#> for mysql connection\n";
  print "  -user <name>           : use user <name> to connect to compara DB\n";
  print "  -pass <pass>           : use password to connect to compara DB\n";
  print "  -dbname <name>         : use database <name> to connect to compara DB\n";
  print "  -member_id <id>        : member_id of query member\n";
  print "  -logic_name <name>     : logic_name of analysis\n";
  print "LaunchBlastRunnable.pl v1.0\n";
  
  exit(1);  
}

sub displayHSP {
  my($feature) = @_;
  
  my $percent_ident = int($feature->identical_matches*100/$feature->alignment_length);
  my $pos = int($feature->positive_matches*100/$feature->alignment_length);
  
=head3
  print("pep_align_feature :\n" . 
    " seqname           : $feature->seqname\n" .
    " start             : $feature->start\n" .
    " end               : $feature->end\n" .
    " hseqname          : $feature->hseqname\n" .
    " hstart            : $feature->hstart\n" .
    " hend              : $feature->hend\n" .
    " score             : $feature->score\n" .
    " p_value           : $feature->p_value\n" .
    " identical_matches : $feature->identical_matches\n" .
    " pid               : $percent_ident\n" .
    " positive_matches  : $feature->positive_matches\n" .
    " pos               : $pos\n" .
    " cigar_line        : $feature->cigar_string\n");
=cut
}


sub testBlastRunnableDB
{
  my($db, $member_id) = @_;
  
  my $analysis = $db->get_AnalysisAdaptor->fetch_by_logic_name('homology_blast_10116');

  my $runnabledb = Bio::EnsEMBL::Pipeline::RunnableDB::BlastComparaPep->new(
                  -db    => $db,
		  -input_id => $member_id,
		  -analysis => $analysis);

  $runnabledb->fetch_input();
  $runnabledb->run;

  # check output
  my @outputs = $runnabledb->output;
  print("have $#outputs outputs\n");
  foreach my $output (@outputs) {
    print("=> $output\n");
    #displayHSP($output);
  }

  $runnabledb->write_output;

  #
  # write_output
  #
  #my $pairAdaptor = new Bio::EnsEMBL::Compara::DBSQL::PairAdaptor($bdb);
  #$pairAdaptor->store($runnable->output);
}


sub testBlastRunnable
{
  my($db, $qy_file, $fastadb) = @_;

  #
  # load peptides from local query fasta file and blast them 
  # against the fasta database
  #

  my $seqio = new Bio::SeqIO(-file => $qy_file, 
                             -format => 'fasta');

  my $number_seq_treated = 0;

  while (my $seq = $seqio->next_seq) {
    my $seqName = $seq->id();
    print("blasting seq '$seqName'\n");

    $number_seq_treated++;

    my $runnable = new Bio::EnsEMBL::Pipeline::Runnable::Blast(-query          => $seq,
                                                               -database       => $fastadb,
                                                               -threshold      => 1e-10,
                                                               -options        => "-filter none -span1 -postsw -V=20 -B=20 -sort_by_highscore -warnings -cpus 1",
                                                               -threshold_type => "PVALUE",
                                                               -program        => "/scratch/local/ensembl/bin/wublastp");

    $runnable->run;
    
    my @outputs = $runnable->output;
    print("have $#outputs outputs\n");
    foreach my $output (@outputs) {
      print("=> $output\n");
      #displayHSP($output);
    }
    
    
    #$db->store($runnable->output);
    #unlink glob("/tmp/*$rand*");
  }

}

