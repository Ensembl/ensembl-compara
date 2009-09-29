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
my %conservation_score_params;
my %healthcheck_conf;
my %engine_params;

my %compara_conf = ();
#$compara_conf{'-user'} = 'ensadmin';
$compara_conf{'-port'} = 3306;

my ($help, $host, $user, $pass, $dbname, $port, $compara_conf, $adaptor);
my ($subset_id, $genome_db_id, $prefix, $fastadir, $verbose);

#list of compara tables to be changed to InnoDB
my @dna_pipeline_tables = qw(genomic_align_block genomic_align genomic_align_group genomic_align_tree sequence dnafrag_region constrained_element conservation_score);


# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

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

$self->parse_conf($conf_file);

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

$self->{'comparaDBA'}   = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf);
$self->{'hiveDBA'}      = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);

$self->set_hive_metadata();

$self->set_storage_engine();


$self->setup_pipeline();

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "loadMultipleAlignerSystem.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates\n";
  print "loadMultipleAlignerSystem.pl v1.0\n";
  
  exit(1);  
}


sub parse_conf {
  my $self = shift;
  my($conf_file) = shift;

  $self->{'set_internal_ids'} = 0;

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
      elsif($type eq 'SET_INTERNAL_IDS') {
	  $self->{'set_internal_ids'} = 1;
      }
      elsif($type eq 'CONSERVATION_SCORE') {
        die "You cannot have more than one CONSERVATION_SCORE block in your configuration file"
            if (%conservation_score_params);
        %conservation_score_params = %{$confPtr};
      }
      elsif($type eq 'HEALTHCHECKS') {
	  %healthcheck_conf = %{$confPtr};
      }
      elsif($type eq 'ENGINE') {
	  %engine_params = %{$confPtr};
      }
    }
  }
}


#####################################################################
##
## set_hive_metadata
##
#####################################################################

sub set_hive_metadata {
  my ($self, %hive_params) = @_;

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
}
#####################################################################
##
## set_storage_engine
##
#####################################################################

sub set_storage_engine {
    my ($self) = @_;

    if (%engine_params) {
	if (defined ($engine_params{'dna_pipeline'}) && $engine_params{'dna_pipeline'} ne "") {
	    #Change tables to ENGINE
	    my $engine = $engine_params{'dna_pipeline'};
	    if (lc($engine) ne "innodb" && lc($engine) ne "myisam") {
		print "engine2 $engine\n";
		die ("\nERROR!! $engine is not supported. ENGINE type must be either InnoDB or MyISAM\n");
	    }
	    foreach my $table (@dna_pipeline_tables) {
		my $sql = "ALTER TABLE $table ENGINE=$engine";
		$self->{'hiveDBA'}->dbc->do($sql);
	    }
	}
	#defined individual tables
	foreach my $table (keys %engine_params) {
	    next if ($table eq 'dna_pipeline' || $table eq "" || $table eq "TYPE");
	    my $engine = $engine_params{$table};
	    if (lc($engine) ne "innodb" && lc($engine) ne "myisam") {
		die ("\nERROR!! $engine is not supported. ENGINE type must be either InnoDB or MyISAM\n");
	    }
	    my $sql = "ALTER TABLE $table ENGINE=$engine";
	    $self->{'hiveDBA'}->dbc->do($sql);
	}
    }
}


#####################################################################
##
## setup_hive_metadata
##
#####################################################################

sub setup_pipeline
{
  #yes this should be done with a config file and a loop, but...
  my $self = shift;

  my $dataflowRuleDBA = $self->{'hiveDBA'}->get_DataflowRuleAdaptor;
  my $ctrlRuleDBA = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;
  $self->{'analysisStatsDBA'} = $self->{'hiveDBA'}->get_AnalysisStatsAdaptor;
  my $stats;

  # ANALYSIS 1 - SubmitGenome
  my $submit_genome_analysis = $self->create_submit_genome_analysis();

  # ANALYSIS 2 - GenomeLoadExonMembers
  my $genome_load_exon_member_analysis = $self->create_member_loading_analysis(%member_loading_params);

  # DATA FLOW from SubmitGenome (1) to GenomeLoadExonMembers (2)
  $dataflowRuleDBA->create_rule($submit_genome_analysis, $genome_load_exon_member_analysis);

  # ANALYSIS 3 - GenomeSubmitPep
  my $genome_submitpep_analysis = $self->create_genome_submitpep_analysis();

  # DATA FLOW from GenomeLoadExonMembers (2) to GenomeSubmitPep (3)
  $dataflowRuleDBA->create_rule($genome_load_exon_member_analysis, $genome_submitpep_analysis);

  # ANALYSIS 4 - GenomeDumpFasta
  my $genome_dumpfasta_analysis = $self->create_genome_dumpfasta_analysis(%analysis_template);

  # DATA FLOW from GenomeLoadExonMembers (2) to GenomeDumpFasta (4)
  $dataflowRuleDBA->create_rule($genome_load_exon_member_analysis, $genome_dumpfasta_analysis);

  # ANALYSIS 5 - SyntenyMapBuilder
  my $synteny_map_builder_analysis = $self->create_synteny_map_builder_analysis(%synteny_map_builder_params);

  # ANALYSIS 6 - CreateBlastRules
  #    (it comes before SyntenyMapBuilder in the pipeline but needs to know about
  #    the logic_name of the SyntenyMapBuilder)
  my $parameters = "{phylumBlast=>0, selfBlast=>0,cr_analysis_logic_name=>'".
      $synteny_map_builder_analysis->logic_name."'}";
  my $create_blast_rules_analysis = $self->create_create_blast_rules_analysis($parameters);

  # DATA FLOW from GenomeDumpFasta (4) to CreateBlastRules (6)
  $dataflowRuleDBA->create_rule($genome_dumpfasta_analysis, $create_blast_rules_analysis);

  # CreateBlastRules (6) has to wait for GenomeLoadExonMembers (2), GenomeSubmitPep (3)
  # and GenomeDumpFasta (4) before running:
  $ctrlRuleDBA->create_rule($genome_load_exon_member_analysis, $create_blast_rules_analysis);
  $ctrlRuleDBA->create_rule($genome_submitpep_analysis, $create_blast_rules_analysis);
  $ctrlRuleDBA->create_rule($genome_dumpfasta_analysis, $create_blast_rules_analysis);

  # SyntenyMapBuilder (5) has to wait for CreateBlastRules (6) and all the SubmitPep_* and
  # blast_* analyses created by the GenomeSubmitPep and GenomeDumpFasta jobs. The extra
  # control rules from the SubmitPep_* and blast_* analyses are created by the
  # CreateBlastRules jobs.
  $ctrlRuleDBA->create_rule($create_blast_rules_analysis, $synteny_map_builder_analysis);


  # ANALYSIS 10 - SetInternalIds
  #This analysis becomes before MultipleAligner analyses but needs to be in 
  #the loop that creates them and so is called from within the  
  #$self->create_multiple_aligner_analysis module

  # ANALYSIS 8 - Conservation scores
  my $conservation_score_analysis = $self->create_conservation_score_analysis(%conservation_score_params);

  # ANALYSIS 9 - MultipleAligner
  my $multiple_aligner_analysis = $self->create_multiple_aligner_analysis($multiple_aligner_params, $synteny_map_builder_analysis,
      $conservation_score_analysis);

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


#####################################################################
##
## create_submit_genome_analysis
##
#####################################################################

sub create_submit_genome_analysis {
  my ($self) = @_;

  my $submit_genome_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'SubmitGenome',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy'
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($submit_genome_analysis);
  my $stats = $self->{'analysisStatsDBA'}->fetch_by_analysis_id($submit_genome_analysis->dbID);
  $stats->batch_size(7000);
  $stats->hive_capacity(-1);
  $stats->update();

  return $submit_genome_analysis;
}


#####################################################################
##
## create_member_loading_analysis
##
#####################################################################

sub create_member_loading_analysis {
  my ($self, %member_loading_params) = @_;

  my $parameters = "{'min_length'=>".$member_loading_params{'exon_min_length'}."}";
  my $member_loading_analysis = Bio::EnsEMBL::Pipeline::Analysis->new
    (-db_version      => '1',
     -logic_name      => 'GenomeLoadExonMembers',
     -input_id_type   => 'genome_db_id',
     -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadExonMembers',
     -parameters      => $parameters);
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($member_loading_analysis);
  my $stats = $self->{'analysisStatsDBA'}->fetch_by_analysis_id($member_loading_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(-1); #unlimited
  $stats->update();

  return $member_loading_analysis;
}


#####################################################################
##
## create_genome_submitpep_analysis
##
#####################################################################

sub create_genome_submitpep_analysis {
  my ($self) = @_;

  my $genome_submitpep_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeSubmitPep',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeSubmitPep'
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($genome_submitpep_analysis);
  my $stats = $self->{'analysisStatsDBA'}->fetch_by_analysis_id($genome_submitpep_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(3);
  $stats->update();

  return $genome_submitpep_analysis
}


#####################################################################
##
## create_genome_dumpfasta_analysis
##
#####################################################################

sub create_genome_dumpfasta_analysis {
  my ($self, %analysis_template) = @_; 

  my $genome_dumpfasta_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeDumpFasta',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta',
      -parameters      => 'fasta_dir=>'.$analysis_template{fasta_dir}.',',
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($genome_dumpfasta_analysis);
  my $stats = $self->{'analysisStatsDBA'}->fetch_by_analysis_id($genome_dumpfasta_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->update();

  return $genome_dumpfasta_analysis;
}


#####################################################################
##
## create_synteny_map_builder_analysis
##
#####################################################################

sub create_synteny_map_builder_analysis {
  my ($self, %synteny_map_builder_params) = @_;

  my $parameters = "";
  my ($logic_name, $module) = set_logic_name_and_module(\%synteny_map_builder_params, "Mercator");

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
      -logic_name      => $logic_name,
      -module          => $module,
      -parameters      => $parameters
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($synteny_map_builder_analysis);
  my $stats = $self->{'analysisStatsDBA'}->fetch_by_analysis_id($synteny_map_builder_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->status('BLOCKED');
  $stats->update();

  return $synteny_map_builder_analysis;
}


#####################################################################
##
## create_create_blast_rules_analysis
##
#####################################################################

sub create_create_blast_rules_analysis {
  my ($self, $parameters) = @_;

  my $create_blast_rules_analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateBlastRules',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::CreateBlastRules',
      -parameters      => $parameters
    );
  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($create_blast_rules_analysis);
  my $stats = $self->{'analysisStatsDBA'}->fetch_by_analysis_id($create_blast_rules_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->status('BLOCKED');
  $stats->update();

  return $create_blast_rules_analysis;
}


#####################################################################
##
## create_multiple_aligner_analysis
##
#####################################################################

sub create_multiple_aligner_analysis {
  my ($self, $multiple_aligner_params, $synteny_map_builder_analysis, $conservation_score_analysis) = @_;

  my $dataflowRuleDBA = $self->{'hiveDBA'}->get_DataflowRuleAdaptor;
  my $ctrlRuleDBA = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;

  foreach my $this_multiple_aligner_params (@$multiple_aligner_params) {

    my ($this_logic_name, $this_module) = set_logic_name_and_module(
        $this_multiple_aligner_params, "Pecan");

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

    #add entry into meta table linking gerp to it's multiple aligner mlss_id
    if (defined($this_multiple_aligner_params->{gerp_mlss_id})) {
	my $key = "gerp_" . $this_multiple_aligner_params->{gerp_mlss_id};
	my $value = $mlss->dbID;
	$self->{'comparaDBA'}->get_MetaContainer->store_key_value($key, $value);
    }

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
        my $tree_file = $this_multiple_aligner_params->{'tree_file'};
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
    my $parameters = "";

    if (defined $this_multiple_aligner_params->{'max_block_size'}) {
	$parameters .= "max_block_size=>" . $this_multiple_aligner_params->{'max_block_size'} .",";
    }
    
    if (defined $this_multiple_aligner_params->{'java_options'}) {
	$parameters .= "java_options=>\'" . $this_multiple_aligner_params->{'java_options'} ."\',";
    }
    $parameters = "{$parameters}";

    my $multiple_aligner_analysis = Bio::EnsEMBL::Analysis->new(
        -logic_name      => $this_logic_name,
        -module          => $this_module,
        -parameters      => $parameters
      );
    $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($multiple_aligner_analysis);
    my $stats = $self->{'analysisStatsDBA'}->fetch_by_analysis_id($multiple_aligner_analysis->dbID);
    $stats->batch_size(1);
    $stats->hive_capacity(200);
    $stats->status('BLOCKED');
    $stats->update();

    if ($self->{'set_internal_ids'}) {
	my $set_internal_ids_analysis = $self->create_set_internal_ids_analysis($mlss->dbID);
	$ctrlRuleDBA->create_rule($synteny_map_builder_analysis,$set_internal_ids_analysis);
	
	 $ctrlRuleDBA->create_rule($set_internal_ids_analysis, $multiple_aligner_analysis);
     }

    $dataflowRuleDBA->create_rule($synteny_map_builder_analysis, $multiple_aligner_analysis);
    $ctrlRuleDBA->create_rule($synteny_map_builder_analysis, $multiple_aligner_analysis);
    
    $dataflowRuleDBA->create_rule($multiple_aligner_analysis, $conservation_score_analysis);
    $ctrlRuleDBA->create_rule($multiple_aligner_analysis, $conservation_score_analysis);
  }
}

#####################################################################
##
## create_set_internal_ids_analysis
##
#####################################################################
sub create_set_internal_ids_analysis {
    my ($self, $mlss_id) = @_;
    
    #
    # Creating SetInternalIds analysis
    #
    my $stats;
    my $setInternalIdsAnalysis = Bio::EnsEMBL::Analysis->new(
#        -db_version      => '1',
        -logic_name      => 'SetInternalIds',
        -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SetInternalIds',
#        -parameters      => ""
      );

    $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($setInternalIdsAnalysis);
    $stats = $self->{'analysisStatsDBA'}->fetch_by_analysis_id($setInternalIdsAnalysis->dbID);
    #$stats = $fixInternalIdsAnalysis->stats;
    $stats->batch_size(1);
    $stats->hive_capacity(1); 
    $stats->update();
    $self->{'setInternalIdsAnalysis'} = $setInternalIdsAnalysis;

    my $input_id =  "method_link_species_set_id=>$mlss_id";

    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
            -input_id       => "{$input_id}",
            -analysis       => $setInternalIdsAnalysis
    );
    return $setInternalIdsAnalysis;

}

#####################################################################
##
## create_conservation_score_analysis
##
#####################################################################

sub create_conservation_score_analysis {
  my ($self, %conservation_score_params) = @_;

  return undef if (!%conservation_score_params);
  
  my ($logic_name, $module) = set_logic_name_and_module(
      \%conservation_score_params, "Gerp");

  my ($method_link_id, $method_link_type);
  my ($method_link_id_cs, $method_link_type_cs) = qw(501 GERP_CONSERVATION_SCORE);
  my ($method_link_id_ce, $method_link_type_ce) = qw(11 GERP_CONSTRAINED_ELEMENT);
  if (defined $conservation_score_params{'method_links'}) {
      foreach my $method_link (@{$conservation_score_params{'method_links'}}) {
	  ($method_link_id, $method_link_type) = @$method_link;

	  if ($method_link_type eq "GERP_CONSERVATION_SCORE") {
	      $method_link_id_cs = $method_link_id;
	      $method_link_type_cs = $method_link_type;
	  }
	  if ($method_link_type eq "GERP_CONSTRAINED_ELEMENT") {
	      $method_link_id_ce = $method_link_id;
	      $method_link_type_ce = $method_link_type;
	  }
      }
  }

  my $sql = "INSERT ignore into method_link SET method_link_id=$method_link_id_cs, type='$method_link_type_cs'";
  $self->{'hiveDBA'}->dbc->do($sql);

  $sql = "INSERT ignore into method_link SET method_link_id=$method_link_id_ce, type='$method_link_type_ce'";
  $self->{'hiveDBA'}->dbc->do($sql);

  foreach my $this_multiple_aligner_params (@$multiple_aligner_params) {
      foreach my $method_link_type ($method_link_type_cs, $method_link_type_ce) {

	  my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
	  $mlss->method_link_type($method_link_type);
	  
	  my $gdbs = [];
	  
	  foreach my $gdb_id (@{$this_multiple_aligner_params->{'species_set'}}) {
	      my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
	      push @{$gdbs}, $gdb;
	  }
	  $mlss->species_set($gdbs);

	  #use method_link_species_set id from config file if defined
	  if ($method_link_type eq "GERP_CONSERVATION_SCORE") {
	      if (defined($conservation_score_params{'method_link_species_set_id_cs'})) {
		  $mlss->dbID($conservation_score_params{'method_link_species_set_id_cs'});
	      }
	  } else {
	      if (defined($conservation_score_params{'method_link_species_set_id_ce'})) {
		  $mlss->dbID($conservation_score_params{'method_link_species_set_id_ce'});
	      }
	  }
	  
	  $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);

	  #add gerp conservation score mlss id for use in 
	  #create_multiple_aligner_analysis to create entry into meta table
	  if ($method_link_type eq "GERP_CONSERVATION_SCORE") {
	      $this_multiple_aligner_params->{gerp_mlss_id} = $mlss->dbID;
	  }
      }
  }

  my $parameters = "";
  if (defined $conservation_score_params{'param_file'}) {
    $parameters .= "param_file=>\'" . $conservation_score_params{'param_file'} ."\',";
  }
  if (defined $conservation_score_params{'window_sizes'}) {
    $parameters .= "window_sizes=>\'" . $conservation_score_params{'window_sizes'} ."\',";
  }
  if (defined $conservation_score_params{'tree_file'}) {
    $parameters .= "tree_file=>\'" . $conservation_score_params{'tree_file'} ."\',";
  }

  $parameters .= "constrained_element_method_link_type=>\'" . $method_link_type_ce ."\',";

  $parameters = "{$parameters}";

  #default program_version
  my $program_version = 2.1;
  if (defined $conservation_score_params{'program_version'}) {
    $program_version = $conservation_score_params{'program_version'};
  }
  
  #location of program_file
  my $program_file = "/software/ensembl/compara/gerp/GERPv2.1";
  if (defined $conservation_score_params{'program_file'}) {
    $program_file = $conservation_score_params{'program_file'};
  }

  my $conservation_score_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => $logic_name,
      -module          => $module,
      -parameters      => $parameters,
      -program_version => $program_version,
      -program_file    => $program_file
    );

  $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($conservation_score_analysis);
  my $stats = $self->{'analysisStatsDBA'}->fetch_by_analysis_id($conservation_score_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(60);
  $stats->status('BLOCKED');
  $stats->update();

  foreach my $this_multiple_aligner_params (@$multiple_aligner_params) {
      $self->create_conservation_score_healthcheck_analysis($conservation_score_analysis, \%conservation_score_params, $this_multiple_aligner_params);
  }

  return $conservation_score_analysis;
}

sub create_conservation_score_healthcheck_analysis {
     my ($self, $conservation_score_analysis, $conservation_score_params, $multiple_aligner_params) = @_;

     my $ctrlRuleDBA = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;

     my $conservation_score_healthcheck_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'ConservationScoreHealthCheck',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
    );
     
     $self->{'comparaDBA'}->get_AnalysisAdaptor()->store($conservation_score_healthcheck_analysis);
     my $stats = $self->{'analysisStatsDBA'}->fetch_by_analysis_id($conservation_score_healthcheck_analysis->dbID);
     $stats->batch_size(1);
     $stats->hive_capacity(1);
     $stats->status('BLOCKED');
     $stats->update();

     #Create healthcheck analysis_jobs

     #conservation_jobs healthcheck
     my $input_id = "test=>'conservation_jobs',";
     #Use parameters defined in config file if they exist or create default
     #ones based on the method_link_type defined in the MULTIPLE_ALIGNER params
     #and the logic_name defined in the CONSERVATION_SCORE params
     if (defined $healthcheck_conf{'conservation_jobs'}) {
	  $input_id .= $healthcheck_conf{'conservation_jobs'};
     } else {
	 my $params = "";
	 if (defined $conservation_score_params->{'logic_name'}) {
	     $params .= "logic_name=>\'" . $conservation_score_params->{'logic_name'} ."\',";
	 }
	 
	 if ($multiple_aligner_params->{'method_link'}) {
	     my ($method_link_id, $method_link_type) = @{$multiple_aligner_params->{'method_link'}};
	     $params .= "method_link_type=>\'$method_link_type\',";
	 }
	 
	 if ($params ne "") {
	     $input_id .= "params=>{$params}";
	 }
     }
     $input_id = "{$input_id}";
     
     Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
	   -input_id       => $input_id,
	   -analysis       => $conservation_score_healthcheck_analysis
          );
 
     #conservation_scores healthcheck
     $input_id = "test=>'conservation_scores',";
     
     #Use parameters defined in config file if they exist or create default
     #ones based on the gerp_mlss_id 
     if (defined $healthcheck_conf{'conservation_scores'}) {
	 $input_id .= $healthcheck_conf{'conservation_scores'};
     } else {
	 my $params = "";
	 if (defined $multiple_aligner_params->{'gerp_mlss_id'}) {
	     $params .= "method_link_species_set_id=>" . $multiple_aligner_params->{'gerp_mlss_id'};
	 }
	 if ($params ne "") {
	     $input_id .= "params=>{$params}";
	 }
     }

     $input_id = "{$input_id}";

     Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
	   -input_id       => $input_id,
	   -analysis       => $conservation_score_healthcheck_analysis
          );


     $ctrlRuleDBA->create_rule($conservation_score_analysis, $conservation_score_healthcheck_analysis); 
}


#####################################################################
##
## set_logic_name_and_module
##
#####################################################################

sub set_logic_name_and_module {
  my ($params, $default) = @_;

  my $logic_name = $default; #Default value
  if (defined $params->{'logic_name'}) {
    $logic_name = $params->{'logic_name'};
  }
  my $module = "Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::$logic_name";
  if (defined $params->{'module'}) {
    $module = $params->{'module'};
  }

  return ($logic_name, $module);
}
