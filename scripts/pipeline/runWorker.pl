#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Hive::Worker;


# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'db_conf'} = {};
$self->{'db_conf'}->{'-user'} = 'ensro';
$self->{'db_conf'}->{'-port'} = 3306;

$self->{'analysis_id'} = undef;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);

GetOptions('help'           => \$help,
           'conf=s'         => \$conf_file,
           'dbhost=s'       => \$host,
           'dbport=i'       => \$port,
           'dbuser=s'       => \$user,
           'dbpass=s'       => \$pass,
           'dbname=s'       => \$dbname,
           'analysis_id=i'  => \$self->{'analysis_id'},
          );

if ($help) { usage(); }

parse_conf($self, $conf_file);

if($host)   { $self->{'db_conf'}->{'-host'}   = $host; }
if($port)   { $self->{'db_conf'}->{'-port'}   = $port; }
if($dbname) { $self->{'db_conf'}->{'-dbname'} = $dbname; }
if($user)   { $self->{'db_conf'}->{'-user'}   = $user; }
if($pass)   { $self->{'db_conf'}->{'-pass'}   = $pass; }


unless(defined($self->{'db_conf'}->{'-host'})
       and defined($self->{'db_conf'}->{'-user'})
       and defined($self->{'db_conf'}->{'-dbname'}))
{
  print "\nERROR : must specify host, user, and database to connect\n\n";
  usage(); 
}

unless(defined($self->{'analysis_id'})) {
  print "\nERROR : must specify analysis_id of worker\n\n";
  usage();
}

$self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%{$self->{'db_conf'}});
#$self->{'pipelineDBA'} = new Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'});

my $worker = $self->{'comparaDBA'}->get_HiveAdaptor->create_new_worker($self->{'analysis_id'});
die("couldn't create worker for analysis_id ".$self->{'analysis_id'}."\n") unless($worker);

$worker->print_worker();
$worker->run();


exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "runWorker.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara db location\n";
  print "  -dbhost <machine>      : mysql database host <machine>\n";
  print "  -dbport <port#>        : mysql port number\n";
  print "  -dbname <name>         : mysql database <name>\n";
  print "  -dbuser <name>         : mysql connection user <name>\n";
  print "  -dbpass <pass>         : mysql connection password\n";
  print "  -analysis_id <id>      : analysis_id in db\n";
  print "runWorker.pl v1.0\n";
  
  exit(1);  
}


sub parse_conf {
  my $self      = shift;
  my $conf_file = shift;

  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      #print("HANDLE type " . $confPtr->{TYPE} . "\n");
      if(($confPtr->{TYPE} eq 'COMPARA') or ($confPtr->{TYPE} eq 'DATABASE')) {
        $self->{'db_conf'} = $confPtr;
      }
    }
  }
}

