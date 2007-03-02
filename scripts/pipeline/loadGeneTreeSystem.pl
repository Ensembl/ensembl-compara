#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Registry;

my $conf_file;
my %analysis_template;
my @speciesList = ();
my %hive_params;
my %dnds_params;
my %genetree_params;

my %compara_conf = ();
#$compara_conf{'-user'} = 'ensadmin';
$compara_conf{'-port'} = 3306;

my ($help, $host, $user, $pass, $dbname, $port, $compara_conf, $adaptor);
my ($subset_id, $genome_db_id, $prefix, $fastadir, $verbose, $update);

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

Bio::EnsEMBL::Registry->no_version_check(1);

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
      if(($hive_params{'hive_output_dir'} ne "") and !(-d $hive_params{'hive_output_dir'}));
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('hive_output_dir', $hive_params{'hive_output_dir'});
  }
}


$self->build_GeneTreeSystem();

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "loadGeneTreeSystem.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates\n";
  print "loadGeneTreeSystem.pl v1.2\n";
  
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
      if($confPtr->{TYPE} eq 'GENE_TREE') {
        %genetree_params = %{$confPtr};
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

sub build_GeneTreeSystem
{
  #yes this should be done with a config file and a loop, but...
  my $self = shift;

  my $dataflowRuleDBA = $self->{'hiveDBA'}->get_DataflowRuleAdaptor;
  my $ctrlRuleDBA = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;
  my $analysisStatsDBA = $self->{'hiveDBA'}->get_AnalysisStatsAdaptor;
  my $stats;


  #
  # PAFCluster
  #
  my $parameters = $genetree_params{'cluster_params'};
  my $paf_cluster = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'PAFCluster',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::PAFCluster',
      -parameters      => $parameters
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($paf_cluster);
  $stats = $paf_cluster->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->update();


  #
  # Clusterset_staging
  #
  my $clusterset_staging = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Clusterset_staging',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($clusterset_staging);
  $stats = $clusterset_staging->stats;
  $stats->batch_size(-1);
  $stats->hive_capacity(1);
  $stats->update();

  #
  # Muscle
  #
  $parameters = "{'options'=>'-maxiters 2'";
  if (defined $genetree_params{'max_gene_count'}) {
    $parameters .= ",max_gene_count=>".$genetree_params{'max_gene_count'};
  }
  if (defined $genetree_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$genetree_params{'honeycomb_dir'};
  }
  $parameters .= "'}";
  my $muscle = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Muscle',
      -program_file    => '/usr/local/ensembl/bin/muscle',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Muscle',
      -parameters      => $parameters
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($muscle);
  $stats = $muscle->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->update();


  #
  # Muscle_huge
  #
  $parameters = "{'options'=>'-maxiters 1 -diags1 -sv'";
  if (defined $genetree_params{'max_gene_count'}) {
    $parameters .= ",max_gene_count=>".$genetree_params{'max_gene_count'};
  }
  if (defined $genetree_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$genetree_params{'honeycomb_dir'};
  }
  $parameters .= "'}";
  my $muscle_huge = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Muscle_huge',
      -program_file    => '/usr/local/ensembl/bin/muscle',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Muscle',
      -parameters      => $parameters
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($muscle_huge);
  $stats = $muscle_huge->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->update();


  #
  # ClustalW_mpi
  #
#  my $db_file = $genetree_params{'clustalw_mpi_dir'};
#  unless (defined $db_file && -d $db_file) {
#    warn("db_file for ClustalW_mpi is either not defined or the directory does not exist.\n
#Make sure to set up the 'clustalw_mpi_dir' parameter in the GENE_TREE section of your configuration file\n");
#    exit(2);
#  }
#  my $clustalw_mpi = Bio::EnsEMBL::Analysis->new(
#      -logic_name      => 'ClustalW_mpi',
#      -program_file    => '/usr/local/ensembl/bin/clustalw',
#      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::ClustalW',
#      -parameters      => "{'mpi'=>1}",
#      -db_file         => $db_file,
#    );
#  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($clustalw_mpi);
#  $stats = $clustalw_mpi->stats;
#  $stats->batch_size(1);
#  $stats->hive_capacity(-1);
#  $stats->update();


  #
  # ClustalW_parse
  #
#  my $clustalw_parse = Bio::EnsEMBL::Analysis->new(
#      -logic_name      => 'ClustalW_parse',
#      -program_file    => '/usr/local/ensembl/bin/clustalw',
#      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::ClustalW',
#      -parameters      => "{'parse'=>1, 'align'=>0}",
#      -db_file         => $db_file,
#    );
#  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($clustalw_parse);
#  $stats = $clustalw_parse->stats;
#  $stats->batch_size(1);
#  $stats->hive_capacity(-1);
#  $stats->update();


  #
  # NJTREE_PHYML
  #
  $parameters = "{cdna=>1,bootstrap=>1";
  if (defined $genetree_params{'max_gene_count'}) {
    $parameters .= ",max_gene_count=>".$genetree_params{'max_gene_count'};
    $parameters .= ",species_tree_file=>'/lustre/work1/ensembl/avilella/src/ensembl_main/ensembl-compara/scripts/pipeline/species_tree_njtree.taxon_id.nh'";
  }
  if (defined $genetree_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$genetree_params{'honeycomb_dir'};
  }
  $parameters .= "'}";
  my $njtree_phyml = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NJTREE_PHYML',
      -program_file    => '/lustre/work1/ensembl/avilella/bin/i386/njtree',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NJTREE_PHYML',
      -parameters      => $parameters
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($njtree_phyml);
  $stats = $njtree_phyml->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(400);
  $stats->update();

#   #
#   # NJTREE_noboot
#   #
#   $parameters = "{cdna=>1, bootstrap=>0";
#   if (defined $genetree_params{'max_gene_count'}) {
#     $parameters .= ",max_gene_count=>".$genetree_params{'max_gene_count'};
#     $parameters .= ",species_tree_file=>'/lustre/work1/ensembl/avilella/src/ensembl_main/ensembl-compara/scripts/pipeline/species_tree_njtree.taxon_id.nh'";
#   }
#   if (defined $genetree_params{'honeycomb_dir'}) {
#     $parameters .= ",'honeycomb_dir'=>'".$genetree_params{'honeycomb_dir'};
#   }
#   $parameters .= "'}";
#   my $njtree_phyml_noboot = Bio::EnsEMBL::Analysis->new(
#       -logic_name      => 'NJTREE_noboot',
#       -program_file    => '/lustre/work1/ensembl/avilella/bin/i386/njtree',
#       -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NJTREE_PHYML',
#       -parameters      => $parameters
#     );
#   $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($njtree_phyml_noboot);
#   $stats = $njtree_phyml_noboot->stats;
#   $stats->batch_size(1);
#   $stats->hive_capacity(400);
#   $stats->update();


  #
  # BreakPAFCluster
  #
  $parameters = $genetree_params{'breakcluster_params'};
  my $BreakPAFCluster = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'BreakPAFCluster',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::BreakPAFCluster',
      -parameters      => $parameters
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($BreakPAFCluster);
  $stats = $BreakPAFCluster->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(3);
  $stats->update();

  #
  # OrthoTree
  #
  my $with_options_orthotree = 0;
  if (defined $genetree_params{'honeycomb_dir'}) {
    $parameters = "'honeycomb_dir'=>'".$genetree_params{'honeycomb_dir'};
    $with_options_orthotree = 1;
  }
  if (defined $dnds_params{'species_sets'}) {
    $parameters .= 'species_sets=>' . $dnds_params{'species_sets'} . ',method_link_type=>\''.$dnds_params{'method_link_type'}.'\'';
    $with_options_orthotree = 1;
  }
  $parameters = '{' . $parameters .'}' if (1==$with_options_orthotree);

  my $orthotree = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'OrthoTree',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::OrthoTree',
      -parameters      => $parameters
      );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($orthotree);
  $stats = $orthotree->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(200);
  $stats->update();

  # turn these two on if you need dnds from the old homology system
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
    $ctrlRuleDBA->create_rule($orthotree,$CreateHomology_dNdSJob);
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
  # build graph
  #
  $dataflowRuleDBA->create_rule($paf_cluster, $clusterset_staging, 1);
  $dataflowRuleDBA->create_rule($paf_cluster, $muscle, 2);

  $dataflowRuleDBA->create_rule($muscle, $njtree_phyml, 1);
  $dataflowRuleDBA->create_rule($muscle, $muscle_huge, 2);

  $dataflowRuleDBA->create_rule($muscle_huge, $njtree_phyml, 1);
  $dataflowRuleDBA->create_rule($muscle_huge, $BreakPAFCluster, 2);

#  $dataflowRuleDBA->create_rule($phyml, $rap, 1);
#  $dataflowRuleDBA->create_rule($phyml, $phyml_cdna, 2);
#  $dataflowRuleDBA->create_rule($phyml_cdna, $rap, 1);
#  $dataflowRuleDBA->create_rule($phyml_cdna, $BreakPAFCluster, 2);
  $dataflowRuleDBA->create_rule($njtree_phyml, $orthotree, 1);
#  $dataflowRuleDBA->create_rule($njtree_phyml, $njtree_phyml_noboot, 2);
#  $dataflowRuleDBA->create_rule($njtree_phyml_noboot, $orthotree, 1);
#  $dataflowRuleDBA->create_rule($njtree_phyml_noboot, $BreakPAFCluster, 2);
  $dataflowRuleDBA->create_rule($njtree_phyml, $BreakPAFCluster, 2);
  $dataflowRuleDBA->create_rule($BreakPAFCluster, $muscle, 2);
  # dnds bit
#  $dataflowRuleDBA->create_rule($orthotree,$homology_dNdS);

  #
  # create initial job
  #

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
      (
       -input_id       => 1,
       -analysis       => $paf_cluster,
      );

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


