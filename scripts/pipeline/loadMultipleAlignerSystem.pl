#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Pipeline::Rule;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->no_version_check(1);

my $conf_file;
my %analysis_template;
my %hive_params ;
my %member_loading_params;
my %mercator_params;
my %multiplealigner_params;

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

$self->{'comparaDBA'}   = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf);
$self->{'hiveDBA'}      = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);

if(%hive_params) {
  if(defined($hive_params{'hive_output_dir'})) {
    die("\nERROR!! hive_output_dir doesn't exist, can't configure\n  ", $hive_params{'hive_output_dir'} , "\n")
      unless(-d $hive_params{'hive_output_dir'});
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('hive_output_dir', $hive_params{'hive_output_dir'});
  }
}


$self->prepareGenomeAnalysis();

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
  print "loadHomologySystem.pl v1.0\n";
  
  exit(1);  
}


sub parse_conf {
  my($conf_file) = shift;

  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      my $type = $confPtr->{TYPE};
#      delete $confPtr->{TYPE};
      print("HANDLE type $type\n") if($verbose);
      if($type eq 'COMPARA') {
        %compara_conf = %{$confPtr};
      }
      elsif(($type eq 'BLAST_TEMPLATE') or ($confPtr->{TYPE} eq 'BLASTP_TEMPLATE')) {
        %analysis_template = %{$confPtr};
      }
      elsif($type eq 'HIVE') {
        %hive_params = %{$confPtr};
      }
      elsif($type eq 'MEMBER_LOADING') {
        %member_loading_params = %{$confPtr};
      }
      elsif($type eq 'MERCATOR') {
        %mercator_params = %{$confPtr};
      }
      elsif($type eq 'MULTIPLEALIGNER') {
        %multiplealigner_params = %{$confPtr};
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
  my $submit_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'SubmitGenome',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy'
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($submit_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($submit_analysis->dbID);
  $stats->batch_size(7000);
  $stats->hive_capacity(-1);
  $stats->update();

  return $submit_analysis
    unless($analysis_template{fasta_dir});

  #
  # GenomeLoadExonMembers
  #
  my $parameters = "{'min_length'=>".$member_loading_params{'exon_min_length'}."}";
  my $load_analysis = Bio::EnsEMBL::Pipeline::Analysis->new
    (-db_version      => '1',
     -logic_name      => 'GenomeLoadExonMembers',
     -input_id_type   => 'genome_db_id',
     -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadExonMembers',
     -parameters      => $parameters);
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($load_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($load_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(-1); #unlimited
  $stats->update();

  $dataflowRuleDBA->create_rule($submit_analysis, $load_analysis);
#
  # GenomeSubmitPep
  #
  my $submitpep_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
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

  $dataflowRuleDBA->create_rule($load_analysis, $submitpep_analysis);

  if(defined($self->{'pipelineDBA'})) {
    my $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalAnalysis'=>$submitpep_analysis);
    $rule->add_condition($load_analysis->logic_name());
    unless(checkIfRuleExists($self->{'pipelineDBA'}, $rule)) {
      $self->{'pipelineDBA'}->get_RuleAdaptor->store($rule);
    }
  }

  #
  # GenomeDumpFasta
  #
  my $dumpfasta_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
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

  $dataflowRuleDBA->create_rule($load_analysis, $dumpfasta_analysis);

  if(defined($self->{'pipelineDBA'})) {
    my $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalAnalysis'=>$dumpfasta_analysis);
    $rule->add_condition($load_analysis->logic_name());
    unless(checkIfRuleExists($self->{'pipelineDBA'}, $rule)) {
      $self->{'pipelineDBA'}->get_RuleAdaptor->store($rule);
    }
  }

  #
  # CreateBlastRules
  #
  $parameters = "{phylumBlast=>0, selfBlast=>0,cr_analysis_logic_name=>'Mercator'}";
  my $blastrules_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
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

  $dataflowRuleDBA->create_rule($dumpfasta_analysis, $blastrules_analysis);
  $ctrlRuleDBA->create_rule($load_analysis, $blastrules_analysis);
  $ctrlRuleDBA->create_rule($submitpep_analysis, $blastrules_analysis);
  $ctrlRuleDBA->create_rule($dumpfasta_analysis, $blastrules_analysis);

  #
  # Mercator
  #
  $parameters = "";
  if (defined $mercator_params{'strict_map'}) {
    $parameters .= "strict_map => " . $mercator_params{'strict_map'} .",";
  }
  if (defined $mercator_params{'cutoff_score'}) {
    $parameters .= "cutoff_score => " . $mercator_params{'cutoff_score'} .",";
  }
  if (defined $mercator_params{'cutoff_evalue'}) {
    $parameters .= "cutoff_evalue => " . $mercator_params{'cutoff_evalue'} .",";
  }
  $parameters = "{$parameters}";
  my $mercatorAnalysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Mercator',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Mercator',
      -parameters      => $parameters
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($mercatorAnalysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($mercatorAnalysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->status('BLOCKED');
  $stats->update();

  $ctrlRuleDBA->create_rule($blastrules_analysis, $mercatorAnalysis);

  #
  # CreateMercatorJobs
  #
  if (defined $mercator_params{'species_set'}) {
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
        (-input_id       => '{gdb_ids=> [' . join(",",@{$mercator_params{'species_set'}}) . ']}',
         -analysis       => $mercatorAnalysis);
  }

  #
  # Mlagan
  #
  $parameters = "";
  my ($method_link_id, $method_link_type);
  if($multiplealigner_params{'method_link'}) {
    ($method_link_id, $method_link_type) = @{$multiplealigner_params{'method_link'}};
  } else {
    ($method_link_id, $method_link_type) = qw(9 MLAGAN);
  }
  my $sql = "INSERT ignore into method_link SET method_link_id=$method_link_id, type='$method_link_type'";
  $self->{'hiveDBA'}->dbc->do($sql);
  my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $mlss->method_link_type($method_link_type);

  my $gdbs = [];
  foreach my $gdb_id (@{$mercator_params{'species_set'}}) {
    my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
    push @{$gdbs}, $gdb;
  }
  $mlss->species_set($gdbs);
  $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);

  $parameters .= "method_link_species_set_id => " . $mlss->dbID .",";
  if (defined $multiplealigner_params{'tree_file'}) {
    $parameters .= "tree_file => \'" . $multiplealigner_params{'tree_file'} ."\'";
  }
  $parameters = "{$parameters}";
  my $mlaganAnalysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Mlagan',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Mlagan',
      -parameters      => $parameters
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($mlaganAnalysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($mlaganAnalysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->status('BLOCKED');
  $stats->update();

  $dataflowRuleDBA->create_rule($mercatorAnalysis, $mlaganAnalysis);
  $ctrlRuleDBA->create_rule($mercatorAnalysis, $mlaganAnalysis);

  #
  # blast_template
  #
  # create an unlinked analysis called blast_template
  # it will not have rules so it will never execute
  # used to store module,parameters... to be used as template for
  # the dynamic creation of the analyses like blast_1_NCBI34
  my $blast_template = new Bio::EnsEMBL::Pipeline::Analysis(%analysis_template);
  $blast_template->logic_name("blast_template");
  eval { $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($blast_template); };

  return 1;
}
