#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Runnable::BlastDB;

my $conf_file;
my %analysis_template;
my @speciesList = ();

my %db_conf = {};
$db_conf{'-user'} = 'ensadmin';
$db_conf{'-pass'} = 'ensembl';
$db_conf{'-port'} = 3306;

my ($help, $host, $user, $pass, $dbname, $port, $conf_file, $adaptor);
my ($subset_id, $genome_db_id, $prefix, $fastadir);

GetOptions('help' => \$help,
           'conf=s' => \$conf_file,
           'host=s' => \$host,
           'user=s' => \$user,
           'pass=s' => \$pass,
           'dbname=s' => \$dbname,
           'port=i' => \$port,
           #'compara=s' => \$compara_conf,
           'genome_db_id=i' => \$genome_db_id,
           'subset_id=i' => \$subset_id,
           'prefix=s' => \$prefix,
           'fastadir=s' => \$fastadir,
           #'analysis=s' => \$analysis_conf
          );

parse_conf($conf_file);

if($host)   { $db_conf{'-host'}   = $host; }
if($port)   { $db_conf{'-port'}   = $port; }
if($dbname) { $db_conf{'-dbname'} = $dbname; }
if($user)   { $db_conf{'-user'}   = $user; }
if($pass)   { $db_conf{'-pass'}   = $pass; }


=head3
if(-e $compara_conf) {
  my %conf = %{do $compara_conf};

  $host = $conf{'host'} if $conf{host};
  $port = $conf{'port'} if $conf{port};
  $user = $conf{'user'} if $conf{'user'};
  $pass = $conf{'pass'} if $conf{pass};
  $dbname = $conf{'dbname'} if $conf{dbname};
  $adaptor = $conf{'adaptor'} if $conf{adaptor};
}
=cut

if ($help) { usage(); }

unless(defined($db_conf{'-host'}) and defined($db_conf{'-user'}) and defined($db_conf{'-dbname'})) {
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage(); 
}
unless(defined($fastadir) and ($fastadir =~ /^\//)) { 
  print "\nERROR : must specify an full output path for the fasta directory\n\n";
  usage(); 
}


my $comparaDBA = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%db_conf);
my $pipelineDBA = new Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor(-DBCONN => $comparaDBA->dbc);

my @subsets;

#genome_db_id specified on commandline, so figure out subset
if(defined($genome_db_id)) {
  my $ssid = getSubsetIdForGenomeDBId($comparaDBA, $genome_db_id);
  my $subset = $comparaDBA->get_SubsetAdaptor()->fetch_by_dbID($ssid);
  $subset->{genome_db_id} = $genome_db_id;
  push @subsets, $subset;
}

#subset specified so figure out genome_db_id
if(defined($subset_id)) {
  my $gdbid = getGenomeDBIdForSubsetId($comparaDBA, $subset_id );
  my $subset = $comparaDBA->get_SubsetAdaptor()->fetch_by_dbID($subset_id);
  $subset->{genome_db_id} = $gdbid;
  push @subsets, $subset;
}

unless(@subsets) {
  my @genomedbArray = @{$comparaDBA->get_GenomeDBAdaptor()->fetch_all()};
  print("fetched " . $#genomedbArray+1 . " different genome_db from compara\n");

  foreach my $genome_db (@genomedbArray) {
    my $genome_db_id = $genome_db->dbID();

    $subset_id = getSubsetIdForGenomeDBId($comparaDBA, $genome_db_id);
    if(defined($subset_id)) {
      my $subset = $comparaDBA->get_SubsetAdaptor()->fetch_by_dbID($subset_id);
      $subset->{genome_db_id} = $genome_db_id;
      push @subsets, $subset;
    }
  }
}

#
# subsets now allocated, so dump and build analysis
#

print($#subsets+1 . " subsets found for dumping\n");

foreach my $subset (@subsets) {
  my $fastafile = getFastaNameForGenomeDBID($comparaDBA, $genome_db_id);

  # write fasta file
  $comparaDBA->get_SubsetAdaptor->dumpFastaForSubset($subset, $fastafile);

  my $blastdb     = new Bio::EnsEMBL::Pipeline::Runnable::BlastDB (
      -dbfile     => $fastafile,
      -type       => 'PROTEIN');
  $blastdb->run;
  print("registered ". $blastdb->dbname . " for ".$blastdb->dbfile . "\n");

  # do setdb to prepare it as a blast database
  #print("Prepare fasta file as blast database\n");
  #system("setdb $fastafile");

  # set up the analysis and input_id_analysis tables for the pipeline
  SubmitSubsetForAnalysis($comparaDBA, $pipelineDBA, $subset, $blastdb); #uses global DBAs
}

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "comparaDumpGenes.pl -pass {-compara | -host -user -dbname} {-genome_db_id | -subset_id } [options]\n";
  print "  -help                  : print this help\n";
  print "  -compara <path>        : read compara DB connection info from config file <path>\n";
  print "                           which is perl hash file with keys 'host' 'port' 'user' 'dbname'\n";
  print "  -host <machine>        : set <machine> as location of compara DB\n";
  print "  -port <port#>          : use <port#> for mysql connection\n";
  print "  -user <name>           : use user <name> to connect to compara DB\n";
  print "  -pass <pass>           : use password to connect to compara DB\n";
  print "  -dbname <name>         : use database <name> to connect to compara DB\n";
  print "  -genome_db_id <#>      : dump member associated with genome_db_id\n";
  print "  -subset_id <#>         : dump member associated with subset_id\n";
  print "  -fastadir <path>       : dump fasta into directory\n";
  print "  -analysis <conf file>  : fill analysis table using conf file as template\n";
  print "  -prefix <string>       : use <string> as prefix for sequence names in fasta file\n";
  print "comparaDumpGenes.pl v1.0\n";
  
  exit(1);  
}


sub parse_conf {
  my($conf_file) = shift;

  if(-e $conf_file) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      print("HANDLE type " . $confPtr->{TYPE} . "\n");
      if($confPtr->{TYPE} eq 'COMPARA') {
        %db_conf = %{$confPtr};
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

=head3
if(defined($genome_db_id)) {
  my @subsetIds = @{ getSubsetIdsForGenomeDBId($comparaDBA) };

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
	    "AND member.genome_db_id=$genome_db_id;";
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


sub getGenomeDBIdForSubsetId{
  my ($dbh, $subset_id) = @_;
  
  my @genomeIds = ();
  my $genome_db_id;
  
  my $sql = "SELECT distinct member.genome_db_id " .
            "FROM member, subset_member " .
	    "WHERE subset_member.subset_id=$subset_id  ".
	    "AND member.member_id=subset_member.member_id;";
  my $sth = $dbh->prepare( $sql );
  $sth->execute();

  $sth->bind_columns( undef, \$genome_db_id );

  while( $sth->fetch() ) {
    print("found genome_db_id = $genome_db_id for subset_id = $subset_id\n");
    push @genomeIds, $genome_db_id;
  }
  
  $sth->finish();

  if($#genomeIds > 0) {
    warn ("Compara DB: more than 1 subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }
  if($#genomeIds < 0) {
    warn ("Compara DB: no subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }

  return $genomeIds[0];
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
	    "AND member.sequence_id=sequence.sequence_id " .
	    "GROUP BY member.member_id ORDER BY member.stable_id;";

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

  #addAnalysisForSubset($dbh, $subset_id, $fastafile);
  SubmitSubsetForAnalysis($subset_id, $fastafile);

  print("Prepare fasta file as blast database\n");
  system("setdb $fastafile");
}

=head4
sub taxonIDForSubsetID {
  my ($dbh, $subset_id) = @_;

  my $taxon_id = undef;


  my $sql = "SELECT distinct member.taxon_id " .
            "FROM subset_member, member " .
	    "WHERE subset_member.subset_id='$subset_id' ".
	    "AND member.member_id=subset_member.member_id;";
  my $sth = $dbh->prepare( $sql );
  $sth->execute();

  $sth->bind_columns( undef, \$taxon_id );

  if( $sth->fetch() ) {
    print("taxon_id = '$taxon_id'\n");
  }
  $sth->finish();
  return $taxon_id;
}


sub addAnalysisForSubset {
  my($dbh, $subset_id, $fastafile) = @_;

  unless(defined($analysis_conf)) { return; }
  print("read analysis template from '$analysis_conf'\n");

  my %analconf = %{do $analysis_conf};

  my $analysisAdaptor = $dbh->get_AnalysisAdaptor();

  my $taxon_id = taxonIDForSubsetID($dbh, $subset_id);
  my $logic_name = $analconf{logic_name} . "_$taxon_id";
  
  my $analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db              => "subset_id=$subset_id",
      -db_file         => $fastafile,
      -db_version      => '1',
      -logic_name      => $logic_name,
      -program         => $analconf{program},
      -program_version => $analconf{program_version},
      -program_file    => $analconf{program_file},
      -gff_source      => $analconf{gff_source},
      -gff_feature     => $analconf{gff_feature},
      -module          => $analconf{module},
      -module_version  => $analconf{module_version},
      -parameters      => $analconf{parameters},
      -created         => $analconf{created}
    );

  $analysisAdaptor->store($analysis);
} 
=cut

sub SubmitSubsetForAnalysis {
  my($comparaDBA, $pipelineDBA, $subset) = @_;

  print("\nSubmitSubsetForAnalysis\n");

  my $sicDBA = $pipelineDBA->get_StateInfoContainer;

  my $genome = $comparaDBA->get_GenomeDBAdaptor()->fetch_by_dbID($subset->{genome_db_id});
  my $logic_name = "SubmitPep_" . $genome->assembly();

  my $analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db              => "subset_id=" . $subset->dbID().";genome_db_id=".$genome->dbID,
      -db_file         => $subset->dump_loc(),
      -db_version      => '1',
      -logic_name      => $logic_name,
      -input_id_type   => 'MemberPep'
    );

  $pipelineDBA->get_AnalysisAdaptor()->store($analysis);

  #my $host = hostname();
  print("store using sic\n");
  my $errorCount=0;
  my $tryCount=0;
  eval {
    foreach my $member_id (@{$subset->member_id_list()}) {
      eval {
        $tryCount++;
        $sicDBA->store_input_id_analysis($member_id, #input_id
                                         $analysis,
                                         'earth', #execution_host
                                         0 #save runtime NO (ie do insert)
                                        );
      };
      if($@) {
        $errorCount++;
        if($errorCount>42 && ($errorCount/$tryCount > 0.95)) {
          die("too many repeated failed insert attempts, assume will continue for durration. ACK!!\n");
        }
      } # should handle the error, but ignore for now
      if($tryCount>=5) { last; }
    }
  };
  print("CREATED all input_id_analysis\n");

=head3
  #
  # now add the 'blast' analysis
  #
  $logic_name = "blast_" . $genome->assembly();
  my $analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db              => "subset_id=" . $subset->dbID().";genome_db_id=".$genome->dbID,
      -db_file         => $subset->dump_loc(),
      -db_version      => '1',
      -logic_name      => $logic_name,
      -input_id_type   => 'MemberPep'
    );

  $pipelineDBA->get_AnalysisAdaptor()->store($analysis);



  my $logic_name = "blast_" . $species1Ptr->{abrev};
  print("build analysis $logic_name\n");
  my %analParams = %analysis_template;
  $analParams{'-logic_name'}    = $logic_name;
  $analParams{'-input_id_type'} = $species1Ptr->{condition}->input_id_type();
  $analParams{'-db'}            = $species2Ptr->{abrev};
  $analParams{'-db_file'}       = $species2Ptr->{condition}->db_file();
  my $analysis = new Bio::EnsEMBL::Pipeline::Analysis(%analParams);
  $db->get_AnalysisAdaptor->store($analysis);
=cut

}

