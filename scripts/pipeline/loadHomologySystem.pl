#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->no_version_check(1);


my $conf_file;
my %analysis_template;
my @speciesList = ();
my %hive_params ;
my %dnds_params;
my %homology_params;

my %compara_conf = ();
#$compara_conf{'-user'} = 'ensadmin';
$compara_conf{'-port'} = 3306;

my ($help, $host, $user, $pass, $dbname, $port);
my ($verbose, $update);

GetOptions('help'     => \$help,
           'conf=s'   => \$conf_file,
           'dbhost=s' => \$host,
           'dbport=i' => \$port,
           'dbuser=s' => \$user,
           'dbpass=s' => \$pass,
           'dbname=s' => \$dbname,
           'v' => \$verbose,
           'update' => \$update,
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

$self->{'comparaDBA'}   = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf);
$self->{gdba}   = $self->{'comparaDBA'}->get_GenomeDBAdaptor();
$self->{'hiveDBA'}      = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);

if(%hive_params) {
  if(defined($hive_params{'hive_output_dir'})) {
    die("\nERROR!! hive_output_dir doesn't exist, can't configure\n  ", $hive_params{'hive_output_dir'} , "\n")
      if(($hive_params{'hive_output_dir'} ne "") and !(-d $hive_params{'hive_output_dir'}));
    $self->{'comparaDBA'}->get_MetaContainer->delete_key('hive_output_dir');
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('hive_output_dir', $hive_params{'hive_output_dir'});
  }
}


$self->prepareGenomeAnalysis();
$self->create_peptide_align_feature_tables() unless ($update);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "loadHomologySystem.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates\n";
  print "loadHomologySystem.pl v1.2\n";
  
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
      if(($confPtr->{TYPE} eq 'BLAST_TEMPLATE') or ($confPtr->{TYPE} eq 'BLASTP_TEMPLATE')) {
        %analysis_template = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'HIVE') {
        %hive_params = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'dNdS') {
        %dnds_params = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'HOMOLOGY') {
        %homology_params = %{$confPtr};
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
  #yes this should be done with a config file and a loop, but...
  my $self = shift;

  my $dataflowRuleDBA = $self->{'hiveDBA'}->get_DataflowRuleAdaptor;
  my $ctrlRuleDBA = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;
  my $analysisStatsDBA = $self->{'hiveDBA'}->get_AnalysisStatsAdaptor;
  my $stats;

  #
  # SubmitGenome
  #
  my $submit_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'SubmitGenome',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy'
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($submit_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($submit_analysis->dbID);
  $stats->batch_size(100);
  $stats->hive_capacity(-1);
  $stats->update();

  return $submit_analysis
    unless($analysis_template{fasta_dir});

  #
  # GenomeLoadMembers
  #
  my $load_genome = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeLoadMembers',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadMembers'
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($load_genome);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($load_genome->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(-1); #unlimited
  $stats->update();

  $dataflowRuleDBA->create_rule($submit_analysis, $load_genome);

  #
  # LoadUniProt
  #
  my $loadUniProt = Bio::EnsEMBL::Analysis->new(
        -db_version      => '1',
        -logic_name      => 'LoadUniProt',
        -module          => 'Bio::EnsEMBL::Compara::RunnableDB::LoadUniProt',
      );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($loadUniProt);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($loadUniProt->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->status('LOADING');
  $stats->update();


  #
  # BlastSubsetStaging
  #
  my $blastSubsetStaging = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'BlastSubsetStaging',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy'
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($blastSubsetStaging);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($blastSubsetStaging->dbID);
  $stats->batch_size(100);
  $stats->hive_capacity(-1);
  $stats->update();

  $dataflowRuleDBA->create_rule($load_genome, $blastSubsetStaging);
  $dataflowRuleDBA->create_rule($loadUniProt, $blastSubsetStaging, 2);

  #
  # GenomeSubmitPep
  #
  my $submitpep_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeSubmitPep',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeSubmitPep'
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($submitpep_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($submitpep_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(3);
  $stats->update();

  $dataflowRuleDBA->create_rule($blastSubsetStaging, $submitpep_analysis);

  #
  # GenomeDumpFasta
  #
  my $dumpfasta_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeDumpFasta',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta',
      -parameters      => 'fasta_dir=>'.$analysis_template{fasta_dir}.',',
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($dumpfasta_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($dumpfasta_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->update();

  $dataflowRuleDBA->create_rule($blastSubsetStaging, $dumpfasta_analysis);

  #
  # GenomeCalcStats
  #
  my $calcstats_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeCalcStats',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeCalcStats',
      -parameters      => '',
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($calcstats_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($calcstats_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->update();

  $dataflowRuleDBA->create_rule($blastSubsetStaging, $calcstats_analysis);

  #
  # CreateBlastRules
  #
#  my $parameters = "{phylumBlast=>0, selfBlast=>1,cr_analysis_logic_name=>'BuildHomology'}";
  my $parameters = "{phylumBlast=>0, selfBlast=>1,cr_analysis_logic_name=>'UpdatePAFIds'}";
  my $blastrules_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateBlastRules',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::CreateBlastRules',
      -parameters      => $parameters
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($blastrules_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($blastrules_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->status('BLOCKED');
  $stats->update();

  $ctrlRuleDBA->create_rule($load_genome, $blastrules_analysis);
  $ctrlRuleDBA->create_rule($blastSubsetStaging, $blastrules_analysis);
  $ctrlRuleDBA->create_rule($submitpep_analysis, $blastrules_analysis);
  $ctrlRuleDBA->create_rule($dumpfasta_analysis, $blastrules_analysis);

  $dataflowRuleDBA->create_rule($dumpfasta_analysis, $blastrules_analysis);

  #
  # UpdatePAFIds
  #
  $parameters = '{species_sets=>' . $homology_params{'species_sets'} . '}',
  my $updatepafids_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'UpdatePAFIds',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::UpdatePAFIds',
      -parameters      => $parameters
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($updatepafids_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($updatepafids_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->status('BLOCKED');
  $stats->update();

  $ctrlRuleDBA->create_rule($blastrules_analysis, $updatepafids_analysis);

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
      (
       -input_id       => 1,
       -analysis       => $updatepafids_analysis,
      );

  #
  # BuildHomology
  #
  my $buildHomology = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'BuildHomology',
      -input_id_type   => 'homology',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHomology',
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor->store($buildHomology);
  if(defined($self->{'hiveDBA'})) {
    my $stats = $analysisStatsDBA->fetch_by_analysis_id($buildHomology->dbID);
    $stats->batch_size(1);
    $stats->hive_capacity(3);
    $stats->update();
  }

  #
  # CreateBuildHomologyJobs
  #
  my $createBuildHomologyJobs = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'CreateBuildHomologyJobs',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::CreateBuildHomologyJobs',
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($createBuildHomologyJobs);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($createBuildHomologyJobs->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->status('BLOCKED');
  $stats->update();

  $ctrlRuleDBA->create_rule($updatepafids_analysis, $createBuildHomologyJobs);
  #the jobs created by CreateBuildHomologyJobs are flowed on on branch=2
  $dataflowRuleDBA->create_rule($createBuildHomologyJobs, $buildHomology, 2);

  if (defined $homology_params{'species_sets'}) {
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
         -input_id       => '{species_sets=>' . $homology_params{'species_sets'} . '}',
         -analysis       => $createBuildHomologyJobs,
        );
  }

  #
  # blast_template
  #
  # create an unlinked analysis called blast_template
  # it will not have rules so it will never execute
  # used to store module,parameters... to be used as template for
  # the dynamic creation of the analyses like blast_1_NCBI34
  my $blast_template = new Bio::EnsEMBL::Analysis(%analysis_template);
  $blast_template->logic_name("blast_template");
  eval { $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($blast_template); };


  #
  # CreateHomology_dNdSJob
  #
  my $CreateHomology_dNdSJob = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateHomology_dNdSJob',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::CreateHomology_dNdSJobs'
  );
  $self->{'comparaDBA'}->get_AnalysisAdaptor->store($CreateHomology_dNdSJob);
  if(defined($self->{'hiveDBA'})) {
    my $stats = $analysisStatsDBA->fetch_by_analysis_id($CreateHomology_dNdSJob->dbID);
    $stats->batch_size(1);
    $stats->hive_capacity(-1);
    $stats->status('BLOCKED');
    $stats->update();
    $ctrlRuleDBA->create_rule($buildHomology,$CreateHomology_dNdSJob);
  }
  if (defined $dnds_params{'species_sets'}) {
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
        (
         -input_id       => '{species_sets=>' . $dnds_params{'species_sets'} . ',method_link_type=>\''.$dnds_params{'method_link_type'}.'\'}',
         -analysis       => $CreateHomology_dNdSJob,
        );
  }

  #
  # Homology_dNdS
  #
  my $homology_dNdS = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'Homology_dNdS',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Homology_dNdS'
  );
  $self->store_codeml_parameters(\%dnds_params);
  if (defined $dnds_params{'dNdS_analysis_data_id'}) {
    $homology_dNdS->parameters('{dNdS_analysis_data_id=>' . $dnds_params{'dNdS_analysis_data_id'} . '}');
  }
  $self->{'comparaDBA'}->get_AnalysisAdaptor->store($homology_dNdS);
  if(defined($self->{'hiveDBA'})) {
    my $stats = $analysisStatsDBA->fetch_by_analysis_id($homology_dNdS->dbID);
    $stats->batch_size(10);
    $stats->hive_capacity(200);
    $stats->status('BLOCKED');
    $stats->update();
    $ctrlRuleDBA->create_rule($CreateHomology_dNdSJob,$homology_dNdS);
  }

  #
  # Threshold_on_dS
  #
  my $threshold_on_dS = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'Threshold_on_dS',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Threshold_on_dS'
  );
  $self->{'comparaDBA'}->get_AnalysisAdaptor->store($threshold_on_dS);
  if(defined($self->{'hiveDBA'})) {
    my $stats = $analysisStatsDBA->fetch_by_analysis_id($threshold_on_dS->dbID);
    $stats->batch_size(1);
    $stats->hive_capacity(-1);
    $stats->status('BLOCKED');
    $stats->update();
    $ctrlRuleDBA->create_rule($homology_dNdS,$threshold_on_dS);
  }
  if (defined $dnds_params{'species_sets'}) {
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
        (
         -input_id       => '{species_sets=>' . $dnds_params{'species_sets'} . ',method_link_type=>\''.$dnds_params{'method_link_type'}.'\'}',
         -analysis       => $threshold_on_dS,
        );
  }

  return 1;
}

sub store_codeml_parameters
{
  my $self = shift;
  my $dNdS_Conf = shift;

  my $options_hash_ref = $dNdS_Conf->{'codeml_parameters'};
  return unless($options_hash_ref);
  
  my @keys = keys %{$options_hash_ref};
  my $options_string = "{\n";
  foreach my $key (@keys) {
    $options_string .= "'$key'=>'" . $options_hash_ref->{$key} . "',\n";
  }
  $options_string .= "}";

  $dNdS_Conf->{'dNdS_analysis_data_id'} =
         $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($options_string);

  $dNdS_Conf->{'codeml_parameters'} = undef;
}

sub create_peptide_align_feature_tables {
  my $self = shift;
  foreach my $speciesPtr (@speciesList) {
    my $gdb_id = $speciesPtr->{'genome_db_id'};
    my $gdb = $self->{gdba}->fetch_by_dbID($gdb_id);
    my $species_name = lc($gdb->name);
    $species_name =~ s/\ /\_/g;
    my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
    my $sql = "CREATE TABLE $tbl_name like peptide_align_feature";

    #print("$sql\n");
    my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
    $sth->execute();
  }
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

