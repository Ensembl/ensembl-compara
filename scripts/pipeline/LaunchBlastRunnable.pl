#!/usr/bin/perl -w

$| = 1;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBSQL::AnalysisAdaptor;
use Bio::EnsEMBL::Pipeline::RunnableDB::BlastComparaPep;
#use Bio::EnsEMBL::GenePair::DBSQL::PairAdaptor;
use Getopt::Long;

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

if(-e $compara_conf) {
  my %conf = %{do $compara_conf};

  $host = $conf{'host'};
  $port = $conf{'port'};
  $user = $conf{'user'};
  $dbname = $conf{'dbname'};
  $adaptor = $conf{'adaptor'};
}
if ($help) { usage(); }

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

my $analysis = $db->get_AnalysisAdaptor->fetch_by_logic_name('homology_blast_10116');

my $runnabledb = Bio::EnsEMBL::Pipeline::RunnableDB::BlastComparaPep->new(
                -db    => $db,
		-input_id => $member_id,
		-analysis => $analysis);

$runnabledb->fetch_input();
$runnabledb->run;
my @outputs = $runnabledb->output;

print("have $#outputs outputs\n");
foreach my $output (@outputs) {
  print("=> $output\n");
}

#$runnabledb->write_output;


#
# write_output
#

#my $db = new Bio::EnsEMBL::Compara::DBSQL::PairAdaptor($bdb);
#$db->store($runnable->output);
  

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
  print "  -stable_id <id>        : stable_id of query member\n";
  print "  -logic_name <name>     : logic_name of analysis\n";
  print "LaunchBlastRunnable.pl v1.0\n";
  
  exit(1);  
}



