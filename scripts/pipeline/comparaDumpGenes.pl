#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Long;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $conf_file, $adaptor, $subset_id);
my ($genome_db_id, $prefix, $fastafile);

GetOptions('help' => \$help,
           'host=s' => \$host,
           'user=s' => \$user,
           'pass=s' => \$pass,
           'dbname=s' => \$dbname,
	   'port=i' => \$port,
           'conf=s' => \$conf_file,
           'genome_db_id=i' => \$genome_db_id,
           'subset_id=i' => \$subset_id,
	   'prefix=s' => \$prefix,
	   'fasta=s' => \$fastafile
	  );
	  
	  
if(-e $conf_file) {	  
  my %conf = %{do $conf_file};

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
unless(defined($fastafile) and ($fastafile =~ /^\//)) { 
  print "\nERROR : must specify an full output path for the fasta file\n\n";
  usage(); 
}
unless(defined($genome_db_id) or defined($subset_id)) { help(); }


my $dsn = "DBI:mysql:database=$dbname;host=$host;port=$port";

my $dbh = DBI->connect("$dsn",$user,$pass) 
  || die "Database connection not made: $DBI::errstr";
  
if(defined($genome_db_id)) {
  my @subsetIds = @{ getSubsetIdsForGenomeDBId($dbh) };

  if($#subsetIds > 0) {
    die ("ERROR in Compara DB: more than 1 subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }
  if($#subsetIds < 0) {
    die ("ERROR in Compara DB: no subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }
  $subset_id = $subsetIds[0];
}

unless(defined($subset_id)) {
  die "ERROR : must specify a compara subset to dump fasta from\n";
}
dumpFastaForSubset($dbh, $subset_id);


$dbh->disconnect();
exit(0);



sub usage {
  print "comparaDumpGenes.pl -pass {-compara | -host -user -dbname} {-genome_db_id | -subset_id } [options]\n";
  print "  -help             : print this help\n";
  print "  -compara <path>   : read compara DB connection info from config file <path>\n";
  print "                      which is perl hash file with keys 'host' 'port' 'user' 'dbname'\n";
  print "  -host <machine>   : set <machine> as location of compara DB\n";
  print "  -port <port#>     : use <port#> for mysql connection\n";
  print "  -user <name>      : use user <name> to connect to compara DB\n";
  print "  -pass <pass>      : use password to connect to compara DB\n";
  print "  -dbname <name>    : use database <name> to connect to compara DB\n";
  print "  -genome_db_id <#> : dump member associated with genome_db_id\n";
  print "  -subset_id <#>    : dump member associated with subset_id\n";
  print "  -fasta <path>     : dump fasta to file location\n";
  print "  -prefix <string>  : use <string> as prefix for sequence names in fasta file\n";
  print "comparaDumpGenes.pl v1.0\n";
  
  exit(1);  
}


sub getSubsetIdsForGenomeDBId {
  my ($dbh) = @_;
  
  my @subsetIds = ();
  my $subset_id;
  
  my $sql = "SELECT distinct subset.subset_id " .
            "FROM member, subset, subset_member " .
	    "WHERE subset.subset_id=subset_member.subset_id ".
	    "AND subset.description like '%longest%' ".
	    "AND member.member_id=subset_member.member_id ". 
	    "AND member.genome_db_id=$genome_db_id ";
  my $sth = $dbh->prepare( $sql );
  $sth->execute();

  $sth->bind_columns( undef, \$subset_id );

  while( $sth->fetch() ) {
    print("found subset_id = $subset_id\n");
    push @subsetIds, $subset_id;
  }
  
  $sth->finish();
  print
  return \@subsetIds;
}


sub dumpFastaForSubset {
  my($dbh, $subset_id) = @_;
  
  my $sql = "SELECT member.stable_id, member.description, sequence.sequence " .
            "FROM member, sequence, subset_member " .
	    "WHERE subset_member.subset_id = $subset_id ".
	    "AND member.member_id=subset_member.member_id ". 
	    "AND member.sequence_id=sequence.sequence_id;";

  open FASTAFILE, ">$fastafile" 
    or die "Could open $fastafile for output\n";
  print("writing fasta to loc '$fastafile'\n");

  my $sth = $dbh->prepare( $sql );
  $sth->execute();

  my ($stable_id, $description, $sequence);
  $sth->bind_columns( undef, \$stable_id, \$description, \$sequence );

  while( $sth->fetch() ) {
    $sequence =~ s/(.{72})/$1\n/g;
    print FASTAFILE ">$stable_id $description\n$sequence\n";
  }
  close(FASTAFILE);

  $sth->finish();
  
  #
  # update this subset_id's  subset.dump_loc with the full path of this dumped fasta file
  #
  
  $sth = $dbh->prepare("UPDATE subset SET dump_loc = ? WHERE subset_id = ?");
  $sth->execute($fastafile, $subset_id);
  
}
