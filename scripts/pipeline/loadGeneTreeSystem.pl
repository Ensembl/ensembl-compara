#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::DBLoader;


my $conf_file;
my %analysis_template;
my @speciesList = ();
my %hive_params ;
my %genetree_params;

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
  my $paf_cluster = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'PAFCluster',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::PAFCluster',
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
  my $muscle = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Muscle',
      -program_file    => '/usr/local/ensembl/bin/muscle',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Muscle',
      -parameters      => "{'options'=>'-maxiters 2'}"
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($muscle);
  $stats = $muscle->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->update();


  #
  # Muscle_huge
  #
  my $muscle_huge = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Muscle_huge',
      -program_file    => '/usr/local/ensembl/bin/muscle',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Muscle',
      -parameters      => "{'options'=>'-maxiters 1 -diags1 -sv'}"
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($muscle_huge);
  $stats = $muscle_huge->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->update();


  #
  # ClustalW_mpi
  #
  my $db_file = $genetree_params{'clustalw_mpi_dir'};
  unless (defined $db_file && -d $db_file) {
    warn("db_file for ClustalW_mpi is either not defined or the directory does not exist.\n
Make sure to set up the 'clustalw_mpi_dir' parameter in the GENE_TREE section of your configuration file\n");
    exit(2);
  }
  my $clustalw_mpi = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'ClustalW_mpi',
      -program_file    => '/usr/local/ensembl/bin/clustalw',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::ClustalW',
      -parameters      => "{'mpi'=>1}",
      -db_file         => $db_file,
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($clustalw_mpi);
  $stats = $clustalw_mpi->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->update();


  #
  # ClustalW_parse
  #
  my $clustalw_parse = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'ClustalW_parse',
      -program_file    => '/usr/local/ensembl/bin/clustalw',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::ClustalW',
      -parameters      => "{'parse'=>1, 'align'=>0}",
      -db_file         => $db_file,
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($clustalw_parse);
  $stats = $clustalw_parse->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->update();


  #
  # PHYML
  #
  my $phyml = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'PHYML',
      -program_file    => '/usr/local/ensembl/bin/phyml',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::PHYML',
      -parameters      => "{cdna=>0}"
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($phyml);
  $stats = $phyml->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(400);
  $stats->update();


  #
  # PHYML_cdna
  #
  my $phyml_cdna = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'PHYML_cdna',
      -program_file    => '/usr/local/ensembl/bin/phyml',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::PHYML',
      -parameters      => "{cdna=>1}"
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($phyml_cdna);
  $stats = $phyml->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(400);
  $stats->update();


  #
  # RAP
  #
  my $parameters = $genetree_params{'species_tree_file'};
  my $rap = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'RAP',
      -program_file    => '/usr/opt/java/bin/java -jar /nfs/acari/abel/bin/rap.jar',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::RAP',
      -parameters      => $parameters
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($rap);
  $stats = $rap->stats;
  $stats->batch_size(-1);
  $stats->hive_capacity(100);
  $stats->update();

  #
  # build graph
  #
  $dataflowRuleDBA->create_rule($paf_cluster, $clusterset_staging, 1);
  $dataflowRuleDBA->create_rule($paf_cluster, $muscle, 2);
  
  $dataflowRuleDBA->create_rule($muscle, $phyml, 1);
  $dataflowRuleDBA->create_rule($muscle, $muscle_huge, 2);

  $dataflowRuleDBA->create_rule($muscle_huge, $phyml, 1);
  $dataflowRuleDBA->create_rule($muscle_huge, $clustalw_mpi, 2);

  $dataflowRuleDBA->create_rule($clustalw_mpi, $clustalw_parse, 1);
  $dataflowRuleDBA->create_rule($clustalw_parse, $phyml, 1);

  $dataflowRuleDBA->create_rule($phyml, $rap, 1);
  $dataflowRuleDBA->create_rule($phyml, $phyml_cdna, 2);
  $dataflowRuleDBA->create_rule($phyml_cdna, $rap, 1);

  #$ctrlRuleDBA->create_rule($load_genome, $blastrules_analysis);


  #
  # create initial job
  #

  my $input_id = $genetree_params{'cluster_params'};
  if(defined($input_id)) {
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
        (
         -input_id       => $input_id,
         -analysis       => $paf_cluster,
        );
  }


  return 1;
}



