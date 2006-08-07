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
my %synteny_map_builder_params;
my $multiple_aligner_params;

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

if (%hive_params) {
  if (defined($hive_params{'hive_output_dir'})) {
    die("\nERROR!! hive_output_dir doesn't exist, can't configure\n  ", $hive_params{'hive_output_dir'} , "\n")
      if(($hive_params{'hive_output_dir'} ne "") and !(-d $hive_params{'hive_output_dir'}));
    $self->{'comparaDBA'}->get_MetaContainer->delete_key('hive_output_dir');
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('hive_output_dir', $hive_params{'hive_output_dir'});
  }
  if (defined($hive_params{'name'})) {
    $self->{'comparaDBA'}->get_MetaContainer->delete_key('name');
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('name', $hive_params{'name'});
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
      elsif(($type eq 'BLAST_TEMPLATE') or ($type eq 'BLASTP_TEMPLATE')) {
        die "You cannot have more than one BLAST_TEMPLATE/BLASTP_TEMPLATE block in your configuration file"
            if (%analysis_template);
        %analysis_template = %{$confPtr};
      }
      elsif($type eq 'HIVE') {
        die "You cannot have more than one HIVE block in your configuration file"
            if (%hive_params);
        %hive_params = %{$confPtr};
      }
      elsif($type eq 'MEMBER_LOADING') {
        die "You cannot have more than one MEMBER_LOADING block in your configuration file"
            if (%member_loading_params);
        %member_loading_params = %{$confPtr};
      }
      elsif($type eq 'SYNTENY_MAP_BUILDER') {
        die "You cannot have more than one SYNTENY_MAP_BUILDER block in your configuration file"
            if (%synteny_map_builder_params);
        %synteny_map_builder_params = %{$confPtr};
      }
      elsif($type eq 'MULTIPLE_ALIGNER') {
        push(@$multiple_aligner_params, $confPtr);
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
  # SyntenyMapBuilder
  #
  $parameters = "";
  my $synteny_map_builder_logic_name = "Mercator"; #Default value
  if (defined $synteny_map_builder_params{'logic_name'}) {
    $synteny_map_builder_logic_name = $synteny_map_builder_params{'logic_name'};
  }
  my $synteny_map_builder_module =
      "Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::$synteny_map_builder_logic_name";
  if (defined $synteny_map_builder_params{'module'}) {
    $synteny_map_builder_module = $synteny_map_builder_params{'module'};
  }

  if (defined $synteny_map_builder_params{'strict_map'}) {
    $parameters .= "strict_map => " . $synteny_map_builder_params{'strict_map'} .",";
  }
  if (defined $synteny_map_builder_params{'cutoff_score'}) {
    $parameters .= "cutoff_score => " . $synteny_map_builder_params{'cutoff_score'} .",";
  }
  if (defined $synteny_map_builder_params{'cutoff_evalue'}) {
    $parameters .= "cutoff_evalue => " . $synteny_map_builder_params{'cutoff_evalue'} .",";
  }
  $parameters = "{$parameters}";
  my $synteny_map_builder_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => $synteny_map_builder_logic_name,
      -module          => $synteny_map_builder_module,
      -parameters      => $parameters
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($synteny_map_builder_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($synteny_map_builder_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->status('BLOCKED');
  $stats->update();

  #
  # CreateBlastRules
  #    (it comes before SyntenyMapBuilder in the pipeline but needs to know about
  #    the logic_name of the SyntenyMapBuilder)
  #
  $parameters = "{phylumBlast=>0, selfBlast=>0,cr_analysis_logic_name=>'$synteny_map_builder_logic_name'}";
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

  $ctrlRuleDBA->create_rule($blastrules_analysis, $synteny_map_builder_analysis);

  #
  # MultipleAligner
  #
  foreach my $this_multiple_aligner_params (@$multiple_aligner_params) {

    my $this_multiple_aligner_logic_name = "Pecan"; #Default value
    if (defined $this_multiple_aligner_params->{'logic_name'}) {
      $this_multiple_aligner_logic_name = $this_multiple_aligner_params->{'logic_name'};
    }
    my $this_multiple_aligner_module =
        "Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::$this_multiple_aligner_logic_name";
    if (defined $this_multiple_aligner_params->{'module'}) {
      $this_multiple_aligner_module = $this_multiple_aligner_params->{'module'};
    }

    my ($method_link_id, $method_link_type);
    if($this_multiple_aligner_params->{'method_link'}) {
      ($method_link_id, $method_link_type) = @{$this_multiple_aligner_params->{'method_link'}};
    } else {
      ($method_link_id, $method_link_type) = qw(10 PECAN);
    }
    my $sql = "INSERT ignore into method_link SET method_link_id=$method_link_id, type='$method_link_type'";
    $self->{'hiveDBA'}->dbc->do($sql);
    my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
    $mlss->method_link_type($method_link_type);

    my $gdbs = [];
    foreach my $gdb_id (@{$this_multiple_aligner_params->{'species_set'}}) {
      my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
      push @{$gdbs}, $gdb;
    }
    $mlss->species_set($gdbs);
    if (defined($this_multiple_aligner_params->{method_link_species_set_id})) {
      $mlss->dbID($this_multiple_aligner_params->{method_link_species_set_id});
    }
    $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);

    ## Create a Synteny Map Builder job per Multiple Aligner
    if (defined $this_multiple_aligner_params->{'species_set'}) {
      my $input_id = 'gdb_ids=> [' . join(",",@{$this_multiple_aligner_params->{'species_set'}}) . ']';
      if (defined $mlss) {
        $input_id .= ",msa_method_link_species_set_id => ".$mlss->dbID();
      }

      my $tree_string;
      if (defined $this_multiple_aligner_params->{'tree_string'}) {
        $tree_string = $this_multiple_aligner_params->{'tree_string'};
      } elsif (defined $this_multiple_aligner_params->{'tree_file'}) {
        open TREE_FILE, $tree_file || throw("Can not open $tree_file");
        $tree_string = join("", <TREE_FILE>);
        close TREE_FILE;
      }
      if ($tree_string) {
        my $tree_string_analysis_data_id =
              $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($tree_string);
        $input_id .= ",tree_analysis_data_id => \'" . $tree_string_analysis_data_id ."\'";
      }

      Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
            -input_id       => "{$input_id}",
            -analysis       => $synteny_map_builder_analysis
          );
    }
  }
  $parameters = "";
  my $multiple_aligner_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => $this_multiple_aligner_logic_name,
      -module          => $this_multiple_aligner_module,
      -parameters      => $parameters
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($multiple_aligner_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($multiple_aligner_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(5);
  $stats->status('BLOCKED');
  $stats->update();

  $dataflowRuleDBA->create_rule($synteny_map_builder_analysis, $multiple_aligner_analysis);
  $ctrlRuleDBA->create_rule($synteny_map_builder_analysis, $multiple_aligner_analysis);

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
