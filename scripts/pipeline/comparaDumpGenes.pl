#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $compara_conf, $adaptor, $subset_id);
my ($genome_db_id, $prefix, $fastadir);

GetOptions('help' => \$help,
           'host=s' => \$host,
           'user=s' => \$user,
           'pass=s' => \$pass,
           'dbname=s' => \$dbname,
	   'port=i' => \$port,
           'compara=s' => \$compara_conf,
           'genome_db_id=i' => \$genome_db_id,
           'subset_id=i' => \$subset_id,
	   'prefix=s' => \$prefix,
	   'fastadir=s' => \$fastadir
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
unless(defined($fastadir) and ($fastadir =~ /^\//)) { 
  print "\nERROR : must specify an full output path for the fasta directory\n\n";
  usage(); 
}


my $compara_db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => $host,
							     -user => $user,
							     -pass => $pass,
							     -dbname => $dbname);

#
# if neither genome_db_id or subset_id specified, dump for all genomes
#

unless(defined($genome_db_id) or defined($subset_id)) { 
  my $genomedbAdaptor = $compara_db->get_GenomeDBAdaptor();

  my @genomedbArray = @{$genomedbAdaptor->fetch_all()};
  my $count = $#genomedbArray;
  print("fetched $count different genome_db from compara\n");

  foreach my $genome_db (@genomedbArray) {
    my $genome_db_id = $genome_db->dbID();  

    $subset_id = getSubsetIdForGenomeDBId($compara_db, $genome_db_id);
    if(defined($subset_id)) {
      my $fastafile = getFastaNameForGenomeDBID($compara_db, $genome_db_id);
      dumpFastaForSubset($compara_db, $subset_id, $fastafile);
    }
    print("\n");
  }
  exit(0);
}


#
# if genome_db_id specified dump for that species, 
# otherwise $subset_id is defined from options
#

if(defined($genome_db_id)) {
  $subset_id = getSubsetIdForGenomeDBId($compara_db, $genome_db_id);
}

unless(defined($subset_id)) {
  die "ERROR : must specify a compara subset to dump fasta from\n";
}

my $fastafile = getFastaNameForSubsetID($compara_db, $subset_id);
dumpFastaForSubset($compara_db, $subset_id, $fastafile);

#$dbh->disconnect();


exit(0);



#######################
#
# subroutines
#
#######################

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
  print "  -fastadir <path>  : dump fasta into directory\n";
  print "  -prefix <string>  : use <string> as prefix for sequence names in fasta file\n";
  print "comparaDumpGenes.pl v1.0\n";
  
  exit(1);  
}

=head3
if(defined($genome_db_id)) {
  my @subsetIds = @{ getSubsetIdsForGenomeDBId($compara_db) };

  if($#subsetIds > 0) {
    die ("ERROR in Compara DB: more than 1 subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }
  if($#subsetIds < 0) {
    die ("ERROR in Compara DB: no subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }
  $subset_id = $subsetIds[0];
}
=cut 

sub getSubsetIdForGenomeDBId {
  my ($dbh, $genome_db_id) = @_;
  
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
    print("found subset_id = $subset_id for genome_db_id = $genome_db_id\n");
    push @subsetIds, $subset_id;
  }
  
  $sth->finish();

  if($#subsetIds > 0) {
    warn ("Compara DB: more than 1 subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }
  if($#subsetIds < 0) {
    warn ("Compara DB: no subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }

  return $subsetIds[0];
}


sub getFastaNameForSubsetID {
  my ($dbh, $subset_id) = @_;
  
  my($name, $species, $assembly);
  
  
  my $sql = "SELECT genome_db.name, genome_db.assembly " .
            "FROM subset_member, member, genome_db " .
	    "WHERE subset_member.subset_id='$subset_id' ".
	    "AND member.member_id=subset_member.member_id ". 
	    "AND member.genome_db_id=genome_db.genome_db_id ".
	    "GROUP BY genome_db.genome_db_id;";
  my $sth = $dbh->prepare( $sql );
  $sth->execute();

  $sth->bind_columns( undef, \$species, \$assembly );

  while( $sth->fetch() ) {
    $species =~ s/\s+/_/g;
    $name = $fastadir . "/" . $species . "_" . $assembly . ".fasta";
    $name =~ s/\/\//\//g;
    print("name = '$name'\n");
  }
  
  $sth->finish();
  return $name;
}


sub getFastaNameForGenomeDBID {
  my ($dbh, $genomeDBID) = @_;
  
  my($name, $species, $assembly);
  
  
  my $sql = "SELECT genome_db.name, genome_db.assembly " .
            "FROM genome_db " .
	    "WHERE genome_db.genome_db_id=$genomeDBID;";
  my $sth = $dbh->prepare( $sql );
  $sth->execute();

  $sth->bind_columns( undef, \$species, \$assembly );

  while( $sth->fetch() ) {
    $species =~ s/\s+/_/g;
    $name = $fastadir . "/" . $species . "_" . $assembly . ".fasta";
    $name =~ s/\/\//\//g;
    print("name = '$name'\n");
  }
  
  $sth->finish();
  return $name;
}


sub dumpFastaForSubset {
  my($dbh, $subset_id, $fastafile) = @_;
  
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
  
  print("Prepare fasta file as blast database\n");
  system("setdb $fastafile");
}
