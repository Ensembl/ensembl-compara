#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::DBLoader;

srand();

my $conf_file;
my %analysis_template;
my @speciesList = ();
my %hive_params ;
my $verbose;
my $help;

my %compara_conf = ();
#$compara_conf{'-user'} = 'ensadmin';
$compara_conf{'-port'} = 3306;

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};


GetOptions('help'     => \$help,
           'conf=s'   => \$conf_file,
           'v' => \$verbose,
          );

if ($help) { usage(); }

$self->parse_conf($conf_file);


unless(defined($compara_conf{'-host'}) and defined($compara_conf{'-user'}) and defined($compara_conf{'-dbname'})) {
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage(); 
}

$self->{'comparaDBA'}   = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf);
$self->{'hiveDBA'}      = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);

if(%hive_params) {
  if(defined($hive_params{'hive_output_dir'})) {
    die("\nERROR!! hive_output_dir doesn't exist, can't configure\n  ", $hive_params{'hive_output_dir'} , "\n")
      unless(-d $hive_params{'hive_output_dir'});
    $self->{'comparaDBA'}->get_MetaContainer->delete_key('hive_output_dir');
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('hive_output_dir', $hive_params{'hive_output_dir'});
  }
}


$self->prepareGenomicAlignSystem;

foreach my $genomicAlignConf (@{$self->{'genomic_align_conf_list'}}) {
  if($genomicAlignConf->{'subtype'} eq 'blastz') {
    $self->prepBlastzPair($genomicAlignConf);
  }
}

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "loadGenomicAlignSystem.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates\n";
  print "loadGenomicAlignSystem.pl v1.1\n";
  
  exit(1);  
}


sub parse_conf {
  my $self = shift;
  my $conf_file = shift;

  $self->{'genomic_align_conf_list'} = [];
  
  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      print("HANDLE type " . $confPtr->{TYPE} . "\n") if($verbose);
      if($confPtr->{TYPE} eq 'COMPARA') {
        %compara_conf = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'HIVE') {
        %hive_params = %{$confPtr};
      }

      if($confPtr->{TYPE} eq 'GENOMIC_ALIGN') {
        push @{$self->{'genomic_align_conf_list'}} , $confPtr;
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
sub prepareGenomicAlignSystem
{
  #yes this should be done with a config file and a loop, but...
  my $self = shift;

  my $dataflowRuleDBA = $self->{'hiveDBA'}->get_DataflowRuleAdaptor;
  my $ctrlRuleDBA = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;
  my $stats;

  #
  # ChunkDna
  #
  my $chunkAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'ChunkDna',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ChunkDna',
      -parameters      => ""
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($chunkAnalysis);
  $stats = $chunkAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1); #unlimited
  $stats->update();
  $self->{'chunkAnalysis'} = $chunkAnalysis;


  #
  # CreateChunkSets
  #
  my $chunkSetAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateChunkSets',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateChunkSets',
      -parameters      => ""
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($chunkSetAnalysis);
  $stats = $chunkSetAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1); #unlimited
  $stats->update();
  $self->{'CreateChunkSets'} = $chunkSetAnalysis;

  $dataflowRuleDBA->create_rule($chunkAnalysis, $chunkSetAnalysis, 2);
  
  #
  # CreateDnaRules
  #
  my $createRulesAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateDnaRules',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateRules',
      -parameters      => ""
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($createRulesAnalysis);
  $stats = $createRulesAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(1); #unlimited
  $stats->update();
  $self->{'createRulesAnalysis'} = $createRulesAnalysis;

  $ctrlRuleDBA->create_rule($chunkAnalysis, $createRulesAnalysis);
  $ctrlRuleDBA->create_rule($chunkSetAnalysis, $createRulesAnalysis);

}



=head3
  { TYPE => GENOMIC_ALIGN,
    'subtype' => 'blastz',
    'method_link' => [1001, 'BLASTZ_RAW'],
    'analysis_template' => {
         '-program'       => 'blastz',
         '-parameters'    => "{options=>'T=2 L=3000 H=2200 M=40000000 O=400 E=30 Q=/ecs4/work2/ensembl/jessica/data/ensembl_compara_26_1/MmRn-score.matrix'}",
         '-module'        => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::BlastZ',
    },
    'query' => {
      'genome_db_id'    => 3, #RAT
      'chunk_size'      => 30000000,
      'overlap'         => 0,
      'masking_options' => {'default_soft_masking' => 1},
    },
    'target' => {
      'genome_db_id'    => 2, #MOUSE
      'chunk_size'      => 10100000,
      'overlap'         =>   100000,
      'masking_options' => {'default_soft_masking' => 1},
    }
  },
=cut


sub prepBlastzPair
{
  my $self        = shift;
  my $genomic_align_conf  = shift;  #hash reference

  print("PrepBlastzPair\n") if($verbose);

  if($genomic_align_conf->{'method_link'}) {
    my ($method_link_id, $type) = @{$genomic_align_conf->{'method_link'}};
    my $sql = "INSERT ignore into method_link SET method_link_id=$method_link_id, type='$type'";
    print("$sql\n");
    $self->{'hiveDBA'}->dbc->do($sql);
  }
      
  my $hexkey = sprintf("%x", rand(time()));
  print("hexkey = $hexkey\n");

  #
  # blastz_$hexkey_template
  #
  # create an unlinked analysis called blastz_$hexkey_template
  # it will not have rules so it will never execute
  # used to store module,parameters... to be used as template for
  # the dynamic creation of the dbchunk analyses
  my $blastz_template = new Bio::EnsEMBL::Analysis(%{$genomic_align_conf->{'analysis_template'}});
  my $logic_name = "blastz-".$hexkey;
  $blastz_template->logic_name($logic_name);
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($blastz_template);
  my $stats = $blastz_template->stats;
  $stats->hive_capacity(800);
  $stats->update();


  print("  query :\n");
  $genomic_align_conf->{'query'}->{'analysis_job'} = "SubmitBlastZ-$hexkey";
  $self->store_masking_options($genomic_align_conf->{'query'});
  $self->create_chunk_job($genomic_align_conf->{'query'});

  print("  target :\n");
  $genomic_align_conf->{'target'}->{'analysis_template'} = $blastz_template->logic_name;
  $self->store_masking_options($genomic_align_conf->{'target'});
  $self->create_chunk_job($genomic_align_conf->{'target'});

  my $rule_job = "{'from'=>'SubmitBlastZ-$hexkey','to'=>'blastz-$hexkey'}";
  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $rule_job,
        -analysis       => $self->{'createRulesAnalysis'}
        );
  

}


sub store_masking_options
{
  my $self = shift;
  my $chunkingConf = shift;

  my $options_hash_ref = $chunkingConf->{'masking_options'};
  return unless($options_hash_ref);
  
  my @keys = keys %{$options_hash_ref};
  my $options_string = "{\n";
  foreach my $key (@keys) {
    $options_string .= "'$key'=>'" . $options_hash_ref->{$key} . "',\n";
  }
  $options_string .= "}";

  $chunkingConf->{'masking_analysis_data_id'} =
         $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($options_string);
         
  $chunkingConf->{'masking_options'} = undef;
}


sub create_chunk_job
{
  my $self = shift;
  my $chunkingConf = shift;

  my $input_id = "{";
  my @keys = keys %{$chunkingConf};
  foreach my $key (@keys) {
    next unless(defined($chunkingConf->{$key}));
    print("    ",$key," : ", $chunkingConf->{$key}, "\n");
    $input_id .= "'$key'=>'" . $chunkingConf->{$key} . "',";
  }
  $input_id .= "}";

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $self->{'chunkAnalysis'},
        -input_job_id   => 0
        );
  
}

1;

