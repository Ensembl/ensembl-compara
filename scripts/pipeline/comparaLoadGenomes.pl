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
#$self->{'pipelineDBA'} = new Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'});

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
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($submit_analysis);

  return $submit_analysis  
    unless($analysis_template{fasta_dir});

  my $load_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeLoadMembers',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadMembers'
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($load_analysis);

  if(defined($self->{'pipelineDBA'})) {
    my $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalAnalysis'=>$load_analysis);
    $rule->add_condition($submit_analysis->logic_name());
    unless(checkIfRuleExists($self->{'pipelineDBA'}, $rule)) {
      $self->{'pipelineDBA'}->get_RuleAdaptor->store($rule);
    }
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
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($dumpfasta_analysis);

  if(defined($self->{'pipelineDBA'})) {
    my $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalAnalysis'=>$dumpfasta_analysis);
    $rule->add_condition($load_analysis->logic_name());
    unless(checkIfRuleExists($self->{'pipelineDBA'}, $rule)) {
      $self->{'pipelineDBA'}->get_RuleAdaptor->store($rule);
    }
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
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($blastrules_analysis);

  if(defined($self->{'pipelineDBA'})) {
    my $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalAnalysis'=>$blastrules_analysis);
    $rule->add_condition($dumpfasta_analysis->logic_name());
    unless(checkIfRuleExists($self->{'pipelineDBA'}, $rule)) {
      $self->{'pipelineDBA'}->get_RuleAdaptor->store($rule);
    }
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
  eval { $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($blast_template); };

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
  } if(defined($self->{'pipelineDBA'}));

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
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($submitpep_analysis);


  my $blast_analysis = new Bio::EnsEMBL::Pipeline::Analysis(%analysis_template);
  $blast_analysis->logic_name("blast_" . $species->{'genome_db'}->dbID(). "_". $species->{'genome_db'}->assembly());
  $blast_analysis->input_id_type('MemberPep');
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($blast_analysis);

}


