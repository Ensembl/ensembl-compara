#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Pipeline::Rule;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Hive::SimpleRule;
use Bio::EnsEMBL::DBLoader;


my $conf_file;
my %analysis_template;
my @speciesList = ();

my %compara_conf = ();
#$compara_conf{'-user'} = 'ensadmin';
$compara_conf{'-port'} = 3306;

my ($help, $host, $user, $pass, $dbname, $port, $compara_conf, $adaptor);
my ($subset_id, $genome_db_id, $prefix, $fastadir, $verbose);

GetOptions('help'     => \$help,
           'conf=s'   => \$conf_file,
           'dbhost=s' => \$host,
           'dbport=i' => \$port,
           'dbuser=s' => \$user,
           'dbpass=s' => \$pass,
           'dbname=s' => \$dbname,
           'v' => \$verbose,
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

if(%analysis_template and (not(-d $analysis_template{'fasta_dir'}))) {
  die("\nERROR!!\n  ". $analysis_template{'fasta_dir'} . " fasta_dir doesn't exist, can't configure\n");
}

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf);
$self->{'pipelineDBA'} = new Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'});

my $analysis = $self->prepareGenomeAnalysis();

foreach my $speciesPtr (@speciesList) {
  $self->submitGenome($speciesPtr, $analysis);
  #$self->prepareMemberPepAnalyses($speciesPtr);
}


exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "comparaLoadGenomes.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates, and external genome databases\n";
  print "  -dbhost <machine>      : compara mysql database host <machine>\n";
  print "  -dbport <port#>        : compara mysql port number\n";
  print "  -dbname <name>         : compara mysql database <name>\n";
  print "  -dbuser <name>         : compara mysql connection user <name>\n";
  print "  -dbpass <pass>         : compara mysql connection password\n";
  print "comparaLoadGenomes.pl v1.1\n";
  
  exit(1);  
}


sub parse_conf {
  my($conf_file) = shift;

  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      print("HANDLE type " . $confPtr->{TYPE} . "\n") if($verbose);
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


#
# need to make sure analysis 'SubmitGenome' is in database
# this is a generic analysis of type 'genome_db_id'
# the input_id for this analysis will be a genome_db_id
# the full information to access the genome will be in the compara database
# also creates 'GenomeLoadMembers' analysis and
# 'GenomeDumpFasta' analysis in the 'genome_db_id' chain
sub prepareGenomeAnalysis
{
  my $self = shift;

  my $submit_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'SubmitGenome',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Dummy'
    );
  $self->{'pipelineDBA'}->get_AnalysisAdaptor()->store($submit_analysis);

  return $submit_analysis  
    unless($analysis_template{fasta_dir});

  my $load_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeLoadMembers',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadMembers'
    );
  $self->{'pipelineDBA'}->get_AnalysisAdaptor()->store($load_analysis);

  my $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalAnalysis'=>$load_analysis);
  $rule->add_condition($submit_analysis->logic_name());
  unless(checkIfRuleExists($self->{'pipelineDBA'}, $rule)) {
    $self->{'pipelineDBA'}->get_RuleAdaptor->store($rule);
  }
  my $simplerule = Bio::EnsEMBL::Hive::SimpleRule->new(
      '-condition_analysis' => $submit_analysis,
      '-goal_analysis'      => $load_analysis);
  $self->{'comparaDBA'}->get_SimpleRuleAdaptor->store($simplerule);

  
  my $dumpfasta_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeDumpFasta',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta',
      -parameters      => 'fasta_dir=>'.$analysis_template{fasta_dir}.',',
    );
  $self->{'pipelineDBA'}->get_AnalysisAdaptor()->store($dumpfasta_analysis);

  $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalAnalysis'=>$dumpfasta_analysis);
  $rule->add_condition($load_analysis->logic_name());
  unless(checkIfRuleExists($self->{'pipelineDBA'}, $rule)) {
    $self->{'pipelineDBA'}->get_RuleAdaptor->store($rule);
  }
  $simplerule = Bio::EnsEMBL::Hive::SimpleRule->new(
      '-condition_analysis' => $load_analysis,
      '-goal_analysis'      => $dumpfasta_analysis);
  $self->{'comparaDBA'}->get_SimpleRuleAdaptor->store($simplerule);


  my $blastrules_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateBlastRules',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::CreateBlastRules',
      -parameters      => 'fasta_dir=>'.$analysis_template{fasta_dir}.',',
    );
  $self->{'pipelineDBA'}->get_AnalysisAdaptor()->store($blastrules_analysis);

  $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalAnalysis'=>$blastrules_analysis);
  $rule->add_condition($dumpfasta_analysis->logic_name());
  unless(checkIfRuleExists($self->{'pipelineDBA'}, $rule)) {
    $self->{'pipelineDBA'}->get_RuleAdaptor->store($rule);
  }
  $simplerule = Bio::EnsEMBL::Hive::SimpleRule->new(
      '-condition_analysis' => $dumpfasta_analysis,
      '-goal_analysis'      => $blastrules_analysis);
  $self->{'comparaDBA'}->get_SimpleRuleAdaptor->store($simplerule);
  
  
  # create an unlinked analysis called blast_template
  # it will not have rule goal/conditions so it will never execute
  my $blast_template = new Bio::EnsEMBL::Pipeline::Analysis(%analysis_template);
  $blast_template->logic_name("blast_template");
  $blast_template->input_id_type('MemberPep');
  eval { $self->{'pipelineDBA'}->get_AnalysisAdaptor()->store($blast_template); };

  return $submit_analysis;
}


sub checkIfRuleExists
{
  my $dba = shift;
  my $rule = shift;

  my $conditions = $rule->list_conditions;
  
  my $sql = "SELECT rule_id FROM rule_goal ".
            " WHERE rule_goal.goal='" . $rule->goalAnalysis->dbID."'";
  my $sth = $dba->prepare($sql);
  $sth->execute;

  RULE: while( my($ruleID) = $sth->fetchrow_array ) {
    my $sql = "SELECT condition FROM rule_conditions ".
              " WHERE rule_id='$ruleID'";
    my $sth_cond = $dba->prepare($sql);
    $sth_cond->execute;
    while( my($condition) = $sth_cond->fetchrow_array ) {
      my $foundCondition=0;
      foreach my $qcond (@{$conditions}) {
        if($qcond eq $condition) { $foundCondition=1; }
      }
      unless($foundCondition) { next RULE; }      
    }
    $sth_cond->finish;
    # made through all conditions so this is a match
    print("RULE EXISTS as $ruleID\n");
    return $ruleID;
  }
  $sth->finish;
  return undef;
}


sub submitGenome
{
  my $self     = shift;
  my $species  = shift;  #hash reference
  my $analysis = shift;  #reference to Analysis object

  print("SubmitGenome for ".$species->{abrev}."\n") if($verbose);

  #
  # connect to external genome database
  #
  my $locator = $species->{dblocator};
  unless($locator) {
    print("  dblocator not specified, building one\n")  if($verbose);
    $locator = $species->{module}."/host=".$species->{host};
    $species->{port}   && ($locator .= ";port=".$species->{port});
    $species->{user}   && ($locator .= ";user=".$species->{user});
    $species->{pass}   && ($locator .= ";pass=".$species->{pass});
    $species->{dbname} && ($locator .= ";dbname=".$species->{dbname});
  }
  print("    locator = $locator\n")  if($verbose);

  my $genomeDBA;
  eval {
    $genomeDBA = Bio::EnsEMBL::DBLoader->new($locator);
  };

  unless($genomeDBA) {
    print("ERROR: unable to connect to genome database $locator\n\n");
    return;
  }

  my $meta = $genomeDBA->get_MetaContainer;
  my $taxon_id = $meta->get_taxonomy_id;
  my $genome_name = $meta->get_Species->binomial;
  my ($cs) = @{$genomeDBA->get_CoordSystemAdaptor->fetch_all()};
  my $assembly = $cs->version;
  my $genebuild = $meta->get_genebuild;  

  if($species->{taxon_id} && ($taxon_id ne $species->{taxon_id})) {
    throw("$genome_name taxon_id=$taxon_id not as expected ". $species->{taxon_id});
  }

  my $genome = Bio::EnsEMBL::Compara::GenomeDB->new();
  $genome->taxon_id($taxon_id);
  $genome->name($genome_name);
  $genome->assembly($assembly);
  $genome->genebuild($genebuild);
  $genome->locator($locator);
  $genome->dbID($species->{'genome_db_id'}) if(defined($species->{'genome_db_id'}));

 if($verbose) {
    print("  about to store genomeDB\n");
    print("    taxon_id = '".$genome->taxon_id."'\n");
    print("    name = '".$genome->name."'\n");
    print("    assembly = '".$genome->assembly."'\n");
    print("    genome_db id=".$genome->dbID."\n");
  }

  $self->{'comparaDBA'}->get_GenomeDBAdaptor->store($genome);
  $species->{'genome_db'} = $genome;
  print("  STORED as genome_db id=".$genome->dbID."\n");

  #
  # now fill table genome_db_extra
  #
  my ($sth, $sql);
  $sth = $self->{'comparaDBA'}->prepare("SELECT genome_db_id FROM genome_db_extn
      WHERE genome_db_id = ".$genome->dbID);
  $sth->execute;
  my $dbID = $sth->fetchrow_array();
  $sth->finish();

  if($dbID) {
    $sql = "UPDATE genome_db_extn SET " .
              "phylum='" . $species->{phylum}."'".
              ",locator='".$locator."'".
              " WHERE genome_db_id=". $genome->dbID;
  }
  else {
    $sql = "INSERT INTO genome_db_extn SET " .
              " genome_db_id=". $genome->dbID.
              ",phylum='" . $species->{phylum}."'".
              ",locator='".$locator."'";
  }
  print("$sql\n") if($verbose);
  $sth = $self->{'comparaDBA'}->prepare( $sql );
  $sth->execute();
  $sth->finish();
  print("done SQL\n") if($verbose);

  #
  # now configure the input_id_analysis table with the genome_db_id
  #
  my $input_id = "{gdb=>".$genome->dbID."}";
  eval {
    print("about to store_input_id_analysis\n") if($verbose);
    $self->{'pipelineDBA'}->get_StateInfoContainer->store_input_id_analysis(
        $input_id,
        $analysis,     #SubmitGenome analysis
        'gaia',        #execution_host
        0              #save runtime NO (ie do insert)
      );
      print("  stored genome_db_id in input_id_analysis\n") if($verbose);
  };

  $self->{'comparaDBA'}->get_AnalysisJobAdaptor->create_new_job(
      -input_id       => $input_id,
      -analysis_id    => $analysis->dbID,
      -input_job_id   => 0,
      #-block          => 'YES',
      );

}



# Creates the SubmitPep_<genome_db_id>_<assembly> and
# blast__<genome_db_id>_<assembly> analyses for this species/genomeDB
# These analyses exist in the 'MemberPep' chain (input_id_type)
sub prepareMemberPepAnalyses
{
  my $self = shift;
  my $species  = shift;  #hash reference

  my $submitpep_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -logic_name      => "SubmitPep_".$species->{'genome_db'}->dbID()."_".$species->{'genome_db'}->assembly(),
     #-db              => $blastdb->dbname(),
     #-db_file         => $subset->dump_loc(),
     #-db_version      => '1',
      -parameters      => "genome_db_id=>".$species->{'genome_db'}->dbID(), #"subset_id=>".$subset->dbID().
      -input_id_type   => 'MemberPep'
    );
  $self->{'pipelineDBA'}->get_AnalysisAdaptor()->store($submitpep_analysis);


  my $blast_analysis = new Bio::EnsEMBL::Pipeline::Analysis(%analysis_template);
  $blast_analysis->logic_name("blast_" . $species->{'genome_db'}->dbID(). "_". $species->{'genome_db'}->assembly());
  $blast_analysis->input_id_type('MemberPep');
  $self->{'pipelineDBA'}->get_AnalysisAdaptor()->store($blast_analysis);

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


=head4
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


  #
  # now add the 'blast' analysis
  #
  my $logic_name = "blast_" . $genome->assembly();
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


}
=cut
