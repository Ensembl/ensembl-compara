#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
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

foreach my $chunkGroupConf (@{$self->{'chunk_group_conf_list'}}) {
  print("prepChunkGroupJob\n");
  $self->store_masking_options($chunkGroupConf);
  $self->create_chunk_job($chunkGroupConf);
}

foreach my $genomicAlignConf (@{$self->{'genomic_align_conf_list'}}) {
  if($genomicAlignConf->{'subtype'} and ($genomicAlignConf->{'subtype'} eq 'blastz')) {
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
  $self->{'chunk_group_conf_list'} = [];
  $self->{'chunkCollectionHash'} = {};
  
  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      my $type = $confPtr->{TYPE};
      delete $confPtr->{TYPE};
      print("HANDLE type $type\n") if($verbose);
      if($type eq 'COMPARA') {
        %compara_conf = %{$confPtr};
      }
      elsif($type eq 'HIVE') {
        %hive_params = %{$confPtr};
      }
      elsif($type eq 'PAIR_ALIGNER') {
        push @{$self->{'genomic_align_conf_list'}} , $confPtr;
      }
      elsif($type eq 'DNA_COLLECTION') {
        push @{$self->{'chunk_group_conf_list'}} , $confPtr;
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
  # ChunkAndGroupDna
  #
  my $chunkAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'ChunkAndGroupDna',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ChunkAndGroupDna',
      -parameters      => ""
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($chunkAnalysis);
  $stats = $chunkAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1); #unlimited
  $stats->update();
  $self->{'chunkAnalysis'} = $chunkAnalysis;
  
  #
  # CreatePairAlignerJobs
  #
  my $createBlastJobsAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreatePairAlignerJobs',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreatePairAlignerJobs',
      -parameters      => ""
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($createBlastJobsAnalysis);
  $stats = $createBlastJobsAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(1); #unlimited
  $stats->update();
  $self->{'createBlastJobsAnalysis'} = $createBlastJobsAnalysis;

  $ctrlRuleDBA->create_rule($chunkAnalysis, $createBlastJobsAnalysis);

  #
  # FilterDuplicates
  #
  my $filterDuplicatesAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'FilterDuplicates',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::FilterDuplicates',
      -parameters      => ""
    );
  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($filterDuplicatesAnalysis);
  $stats = $filterDuplicatesAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1); #unlimited
  $stats->status('BLOCKED');
  $stats->update();
  $self->{'filterDuplicatesAnalysis'} = $filterDuplicatesAnalysis;

  $dataflowRuleDBA->create_rule($createBlastJobsAnalysis, $filterDuplicatesAnalysis);

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
    my ($method_link_id, $method_link_type) = @{$genomic_align_conf->{'method_link'}};
    my $sql = "INSERT ignore into method_link SET method_link_id=$method_link_id, type='$method_link_type'";
    print("$sql\n");
    $self->{'hiveDBA'}->dbc->do($sql);
        
    #
    # create method_link_species_set
    #
    my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
    $mlss->method_link_type($method_link_type); 
    my $gdb_id1 = $self->{'chunkCollectionHash'}->{$genomic_align_conf->{'query_collection_name'}}->{'genome_db_id'};
    my $gdb_id2 = $self->{'chunkCollectionHash'}->{$genomic_align_conf->{'target_collection_name'}}->{'genome_db_id'};
    printf("create MethodLinkSpeciesSet for genomes %d:%d\n", $gdb_id1, $gdb_id2);
    my $gdb1 = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id1);
    my $gdb2 = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id2);
    $mlss->species_set([$gdb1, $gdb2]);
    $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);
    $self->{'method_link_species_set'} = $mlss;
    $genomic_align_conf->{'method_link_species_set_id'} = $mlss->dbID;
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
  $stats->hive_capacity(350);
  if($genomic_align_conf->{'max_parallel_workers'}) {
    $stats->hive_capacity($genomic_align_conf->{'max_parallel_workers'});
  }
  $stats->update();


  #print("  query :\n");
  #$genomic_align_conf->{'query'}->{'analysis_job'} = "SubmitBlastZ-$hexkey";
  #$self->store_masking_options($genomic_align_conf->{'query'});
  #$self->create_chunk_job($genomic_align_conf->{'query'});

  #print("  target :\n");
  #$genomic_align_conf->{'target'}->{'analysis_template'} = $blastz_template->logic_name;
  #$self->store_masking_options($genomic_align_conf->{'target'});
  #$self->create_chunk_job($genomic_align_conf->{'target'});

  my $rule_job = "{'pair_aligner'=>'" . $blastz_template->logic_name . "'";
  $rule_job .= ",'query_collection_name'=>'"  . $genomic_align_conf->{'query_collection_name'}  . "'";
  $rule_job .= ",'target_collection_name'=>'" . $genomic_align_conf->{'target_collection_name'} . "'";
  $rule_job .= ",'method_link_species_set_id'=>".$genomic_align_conf->{'method_link_species_set_id'} 
    if(defined($genomic_align_conf->{'method_link_species_set_id'}));
  $rule_job .= "}";
  
  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $rule_job,
        -analysis       => $self->{'createBlastJobsAnalysis'}
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
  
  if($chunkingConf->{'collection_name'}) {
    my $collection_name = $chunkingConf->{'collection_name'};
    
    $self->{'chunkCollectionHash'}->{$collection_name} = $chunkingConf;
  }

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

