#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Pipeline::Rule;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::DBLoader;


my $conf_file;
my %analysis_template;
my @speciesList = ();

my %compara_conf = ();
#$compara_conf{'-user'} = 'ensadmin';
$compara_conf{'-port'} = 3306;

my ($help, $host, $user, $pass, $dbname, $port, $compara_conf, $adaptor);
my ($subset_id, $genome_db_id, $prefix, $fastaFile);

GetOptions('help'     => \$help,
           'conf=s'   => \$conf_file,
           'dbhost=s' => \$host,
           'dbport=i' => \$port,
           'dbuser=s' => \$user,
           'dbpass=s' => \$pass,
           'dbname=s' => \$dbname,
           'file=s'   => \$fastaFile,
          );

if ($help) { usage(); }

parse_conf($conf_file);

if($host)   { $compara_conf{'-host'}   = $host; }
if($port)   { $compara_conf{'-port'}   = $port; }
if($dbname) { $compara_conf{'-dbname'} = $dbname; }
if($user)   { $compara_conf{'-user'}   = $user; }
if($pass)   { $compara_conf{'-pass'}   = $pass; }


unless(defined($compara_conf{'-host'}) and defined($compara_conf{'-user'}) and defined($compara_conf{'-dbname'})) {
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage(); 
}

unless(defined($fastaFile)) {
  print "\nERROR : must specify file into which to dump fasta sequences\n\n";
  usage();
}


# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf);
$self->{'pipelineDBA'} = new Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'});

dump_fasta($self, $fastaFile);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "comparaDumpAllPeptides.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates, and external genome databases\n";
  print "  -dbhost <machine>      : compara mysql database host <machine>\n";
  print "  -dbport <port#>        : compara mysql port number\n";
  print "  -dbname <name>         : compara mysql database <name>\n";
  print "  -dbuser <name>         : compara mysql connection user <name>\n";
  print "  -dbpass <pass>         : compara mysql connection password\n";
  print "  -file <path>           : file where fasta dump happens\n";
  print "comparaDumpAllPeptides.pl v1.1\n";
  
  exit(1);  
}


sub parse_conf {
  my($conf_file) = shift;

  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      #print("HANDLE type " . $confPtr->{TYPE} . "\n");
      if($confPtr->{TYPE} eq 'COMPARA') {
        %compara_conf = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'BLAST_TEMPLATE') {
        %analysis_template = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'SPECIES') {
        push @speciesList, $confPtr;
      }
    }
  }
}


sub dump_fasta {
  my($self, $fastafile) = @_;

  my $sql = "SELECT member.stable_id, member.description, sequence.sequence " .
            " FROM member, sequence, source " .
            " WHERE member.source_id=source.source_id ".
            " AND source.source_name='ENSEMBLPEP' ".
            " AND member.sequence_id=sequence.sequence_id " .
            " GROUP BY member.member_id ORDER BY member.stable_id;";

  open FASTAFILE, ">$fastafile"
    or die "Could open $fastafile for output\n";
  print("writing fasta to loc '$fastafile'\n");

  my $sth = $self->{'comparaDBA'}->prepare( $sql );
  $sth->execute();

  my ($stable_id, $description, $sequence);
  $sth->bind_columns( undef, \$stable_id, \$description, \$sequence );

  while( $sth->fetch() ) {
    $sequence =~ s/(.{72})/$1\n/g;
    print FASTAFILE ">$stable_id $description\n$sequence\n";
  }
  close(FASTAFILE);

  $sth->finish();
}
