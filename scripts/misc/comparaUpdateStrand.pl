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
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Compara::Hive::Extensions;



# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'compara_conf'} = {};
$self->{'compara_conf'}->{'-user'} = 'ensro';
$self->{'compara_conf'}->{'-port'} = 3306;

$self->{'speciesList'} = ();

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);
my $genome_db_id;

GetOptions('help'     => \$help,
           'conf=s'   => \$conf_file,
           'dbhost=s' => \$host,
           'dbport=i' => \$port,
           'dbuser=s' => \$user,
           'dbpass=s' => \$pass,
           'dbname=s' => \$dbname,
           'gdb=i'    => \$genome_db_id,
          );

if ($help) { usage(); }

parse_conf($self, $conf_file);

if($host)   { $self->{'compara_conf'}->{'-host'}   = $host; }
if($port)   { $self->{'compara_conf'}->{'-port'}   = $port; }
if($dbname) { $self->{'compara_conf'}->{'-dbname'} = $dbname; }
if($user)   { $self->{'compara_conf'}->{'-user'}   = $user; }
if($pass)   { $self->{'compara_conf'}->{'-pass'}   = $pass; }


unless(defined($self->{'compara_conf'}->{'-host'})
       and defined($self->{'compara_conf'}->{'-user'})
       and defined($self->{'compara_conf'}->{'-dbname'}))
{
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage(); 
}

unless(defined($genome_db_id)) {
  print "\nERROR : must specify genome_db_id\n\n";
  usage();
}

$self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%{$self->{'compara_conf'}});
$self->{'comparaDBA'}->disconnect_when_inactive(0);

$self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
$self->{'coreDBA'} = $self->{'genome_db'}->connect_to_genome_locator();
$self->{'coreDBA'}->disconnect_when_inactive(0);

my $count;
do {
  $count = update_strand($self);
} while($count>0);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "comparaUpdateStrand.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates, and external genome databases\n";
  print "  -dbhost <machine>      : compara mysql database host <machine>\n";
  print "  -dbport <port#>        : compara mysql port number\n";
  print "  -dbname <name>         : compara mysql database <name>\n";
  print "  -dbuser <name>         : compara mysql connection user <name>\n";
  print "  -dbpass <pass>         : compara mysql connection password\n";
  print "  -gdb <int>             : genome_db_id for genomeDB\n";
  print "comparaUpdateStrand.pl v1.1\n";
  
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
      if($confPtr->{TYPE} eq 'COMPARA') {
        $self->{'compara_conf'} = $confPtr;
      }
      if($confPtr->{TYPE} eq 'BLAST_TEMPLATE') {
        $self->{'analysis_template'} = $confPtr;
      }
      if($confPtr->{TYPE} eq 'SPECIES') {
        push @{$self->{'speciesList'}}, $confPtr;
      }
    }
  }
}



sub update_strand {
  my $self         = shift;

  my $db        = $self->{'comparaDBA'};
  my $genome_db = $self->{'genome_db'};

  my $geneDBA        = $self->{'coreDBA'}->get_GeneAdaptor();
  my $transcriptDBA  = $self->{'coreDBA'}->get_TranscriptAdaptor();

  my $sql = "SELECT member.member_id, member.stable_id, source.source_name " .
                         " FROM member, source" .
                         " WHERE member.source_id=source.source_id".
                         " AND member.chr_strand=0".
                         " AND member.genome_db_id=".$genome_db->dbID;
  print("$sql\n");
  my $sth = $db->prepare($sql);
  $sth->execute();

  my ($member_id, $stable_id, $source);
  my $memberCount=0;
  $sth->bind_columns( \$member_id, \$stable_id, \$source );

  while( $sth->fetch() ) {
    $memberCount++;
    my $chr_strand = '0';
    if($source eq 'ENSEMBLGENE') {
      my $gene = $geneDBA->fetch_by_stable_id($stable_id);
      $chr_strand = $gene->seq_region_strand;
    }
    if($source eq 'ENSEMBLPEP') {
      my $transcript = $transcriptDBA->fetch_by_translation_stable_id($stable_id);
      $chr_strand = $transcript->seq_region_strand;
    }

    if($chr_strand ne '0') {
      my $sth_mem = $db->prepare("UPDATE member SET chr_strand=? WHERE member_id=?");
      $sth_mem->execute($chr_strand, $member_id);
      $sth_mem->finish;
      print("converted chr_strand to '$chr_strand' for $stable_id ($member_id)\n");
    }
    else {
      warn("did get valid chr_strand\n");
    }

  }
  $sth->finish();
  return $memberCount;
}
