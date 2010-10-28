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
use Bio::EnsEMBL::Registry;

# Version number updated by cvs
our $VERSION = sprintf "%d.%d", q$Revision$ =~ /: (\d+)\.(\d+)/;

Bio::EnsEMBL::Registry->no_version_check(1);

my $conf_file;
my %hive_params ;
my $verbose;
my $help;

my %compara_conf;
$compara_conf{'-port'} = 3306;
my %healthcheck_conf;

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};


GetOptions('help'     => \$help,
           'conf=s'   => \$conf_file,
           'v' => \$verbose);

if ($help or !defined($conf_file)) { usage(); }

$self->parse_conf($conf_file);


unless(defined($compara_conf{'-host'}) and defined($compara_conf{'-user'}) and defined($compara_conf{'-dbname'})) {
  print "\nERROR : must specify host, user, and database to connect to compara in the configuration file\n\n";
  usage();
}

$self->{'comparaDBA'}       = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf);
$self->{'hiveDBA'}          = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);
$self->{'analysis_adaptor'} = $self->{'hiveDBA'}->get_AnalysisAdaptor;
$self->{'dataflow_adaptor'} = $self->{'hiveDBA'}->get_DataflowRuleAdaptor;
$self->{'ctrlflow_adaptor'} = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;


if(%hive_params) {
  if(defined($hive_params{'hive_output_dir'})) {
    die("\nERROR!! hive_output_dir doesn't exist, can't configure\n  ", $hive_params{'hive_output_dir'} , "\n")
      if(($hive_params{'hive_output_dir'} ne "") and !(-d $hive_params{'hive_output_dir'}));
    $self->{'comparaDBA'}->get_MetaContainer->delete_key('hive_output_dir');
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('hive_output_dir', $hive_params{'hive_output_dir'});
  }
}


#
# creating (another copy of) ChunkAndGroupDna analysis
#
my $stats;
my $noChunkAndGroupDnaAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'NoChunkAndGroupDna',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ChunkAndGroupDna',
      -parameters      => ""
    );
$self->{'analysis_adaptor'}->store($noChunkAndGroupDnaAnalysis);
$stats = $noChunkAndGroupDnaAnalysis->stats;
$stats->batch_size(1);
$stats->hive_capacity(-1); #unlimited
$stats->update();
$self->{'noChunkAndGroupDnaAnalysis'} = $noChunkAndGroupDnaAnalysis;


#
# link to the previously loaded half of the pipeline:
#
if(my $UpdateMaxAlignmentLengthAfterFDanalysis = $self->{'analysis_adaptor'}->fetch_by_logic_name('UpdateMaxAlignmentLengthAfterFD') ) {
    $self->{'ctrlflow_adaptor'}->create_rule($UpdateMaxAlignmentLengthAfterFDanalysis, $noChunkAndGroupDnaAnalysis);
}


$self->{'dna_collection_conf_selected_hash'} = {};
foreach my $chainConf (@{$self->{'chain_conf_list'}}) {
  my $ref_dna_collection_name    = $chainConf->{'reference_collection_name'};
  my $nonref_dna_collection_name = $chainConf->{'non_reference_collection_name'};
  print("filtering DNA_COLLECTIONs used for Chaining('$ref_dna_collection_name','$nonref_dna_collection_name')\n");

  $self->{'dna_collection_conf_selected_hash'}{$ref_dna_collection_name}    = $self->{'dna_collection_conf_full_hash'}{$ref_dna_collection_name}; 
  $self->{'dna_collection_conf_selected_hash'}{$nonref_dna_collection_name} = $self->{'dna_collection_conf_full_hash'}{$nonref_dna_collection_name}; 
}

foreach my $dnaCollectionConf (values %{$self->{'dna_collection_conf_selected_hash'}}) {
  my $dna_collection_name = $dnaCollectionConf->{'collection_name'};
  print("creating ChunkAndGroup jobs for '$dna_collection_name'\n");
  #$self->storeMaskingOptions($dnaCollectionConf);
  $self->createChunkAndGroupDnaJobs($dnaCollectionConf);
}

foreach my $chainConf (@{$self->{'chain_conf_list'}}) {

    my $ref_dna_collection_name    = $chainConf->{'reference_collection_name'};
    my $nonref_dna_collection_name = $chainConf->{'non_reference_collection_name'};

    my $gdb_suffix = $self->{'dna_collection_conf_selected_hash'}{$ref_dna_collection_name}{'genome_db_id'}
               .'-'. $self->{'dna_collection_conf_selected_hash'}{$nonref_dna_collection_name}{'genome_db_id'};

    print "prepareChainSystem($gdb_suffix)\n";
    $self->prepareChainSystem($chainConf, $gdb_suffix);

    #allow 'query_collection_name' or 'reference_collection_name'
    if ($chainConf->{'reference_collection_name'} && !$chainConf->{'query_collection_name'}) {
        $chainConf->{'query_collection_name'} = $chainConf->{'reference_collection_name'};
    }

    #allow 'target_collection_name' or 'non_reference_collection_name'
    if ($chainConf->{'non_reference_collection_name'} && !$chainConf->{'target_collection_name'}) {
        $chainConf->{'target_collection_name'} = $chainConf->{'non_reference_collection_name'};
    }

    $self->create_dump_nib_job($chainConf->{'query_collection_name'});
    $self->create_dump_nib_job($chainConf->{'target_collection_name'});
    $self->prepCreateAlignmentChainsJobs($chainConf);
}

foreach my $netConf (@{$self->{'net_conf_list'}}) {
    my $ref_dna_collection_name    = $netConf->{'reference_collection_name'};
    my $nonref_dna_collection_name = $netConf->{'non_reference_collection_name'};

    my $gdb_suffix = $self->{'dna_collection_conf_selected_hash'}{$ref_dna_collection_name}{'genome_db_id'}
               .'-'. $self->{'dna_collection_conf_selected_hash'}{$nonref_dna_collection_name}{'genome_db_id'};

    print "prepareNetSystem($gdb_suffix)\n";
    $self->prepareNetSystem($netConf, $gdb_suffix);
}

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "loadChainNetSystem.pl $VERSION\n";
  print "loadChainNetSystem.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates\n";
  exit(1);  
}


sub parse_conf {
  my $self = shift;
  my $conf_file = shift;

  $self->{'dna_collection_conf_full_hash'} = {};
  $self->{'chunk_group_conf_list'} = [];
  $self->{'chunkCollectionHash'} = {};
  $self->{'set_internal_ids'} = 0;
  
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
      elsif($type eq 'DNA_COLLECTION') {
        my $dna_collection_name = $confPtr->{'collection_name'};
        $self->{'dna_collection_conf_full_hash'}{$dna_collection_name} = $confPtr;
      }
      elsif($type eq 'CHAIN_CONFIG') {
        push @{$self->{'chain_conf_list'}} , $confPtr;
      }
      elsif($type eq 'NET_CONFIG') {
        push @{$self->{'net_conf_list'}} , $confPtr;
      }
      elsif($type eq 'SET_INTERNAL_IDS') {
	  $self->{'set_internal_ids'} = 1;
      }
      elsif($type eq 'HEALTHCHECKS') {
        %healthcheck_conf = %{$confPtr};
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
sub prepareChainSystem
{
  #yes this should be done with a config file and a loop, but...
  my $self = shift;
  my $chainConf = shift;
  my $gdb_suffix = shift;

  return unless($chainConf);

  my $stats;

  #
  # DumpLargeNibForChains Analysis
  #
  my $dumpLargeNibForChainsAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'DumpLargeNibForChains',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::DumpDnaCollection',
      -parameters      => "{'dump_nib'=>1}"
    );
  $self->{'analysis_adaptor'}->store($dumpLargeNibForChainsAnalysis);
  $stats = $dumpLargeNibForChainsAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->update();
  $self->{'dumpLargeNibForChainsAnalysis'} = $dumpLargeNibForChainsAnalysis;

  $self->{'ctrlflow_adaptor'}->create_rule($noChunkAndGroupDnaAnalysis, $dumpLargeNibForChainsAnalysis);

  #
  # createAlignmentChainsJobs Analysis
  #
  my $sql = "INSERT ignore into method_link SET method_link_id=?, type=?";
  my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);

  my ($input_method_link_id, $input_method_link_type) = @{$chainConf->{'input_method_link'}};

  $sth->execute($input_method_link_id, $input_method_link_type);

  my ($output_method_link_id, $output_method_link_type) = @{$chainConf->{'output_method_link'}};
  $sth->execute($output_method_link_id, $output_method_link_type);
  $sth->finish;

  my $parameters = "{\'method_link\'=>\'$input_method_link_type\'}";

  my $createAlignmentChainsJobsAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateAlignmentChainsJobs',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateAlignmentChainsJobs',
      -parameters      => $parameters
    );
  $self->{'analysis_adaptor'}->store($createAlignmentChainsJobsAnalysis);
  $stats = $createAlignmentChainsJobsAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->update();
  $self->{'createAlignmentChainsJobsAnalysis'} = $createAlignmentChainsJobsAnalysis;

  $self->{'ctrlflow_adaptor'}->create_rule($dumpLargeNibForChainsAnalysis, $createAlignmentChainsJobsAnalysis);

  #
  # AlignmentChains Analysis
  #
  my $max_gap = $chainConf->{'max_gap'};
  my $linear_gap = $chainConf->{'linear_gap'};

  #set default to medium if not defined.
  if (!defined $linear_gap) {
      $linear_gap = "medium";
  }

	my @parameters_array = (
		'input_method_link', $input_method_link_type,
		'output_method_link', $output_method_link_type,
		'max_gap', $max_gap,
		'linear_gap', $linear_gap,
	);
	push(@parameters_array, ('bin_dir', $chainConf->{'bin_dir'})) if defined $chainConf->{'bin_dir'};
	$parameters = generate_paramaters_string(@parameters_array);

  my $alignmentChainsAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'AlignmentChains-'.$gdb_suffix,
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentChains',
      -parameters      => $parameters
    );
  $self->{'analysis_adaptor'}->store($alignmentChainsAnalysis);
  $stats = $alignmentChainsAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(10);
  $stats->update();

  $self->{'alignmentChainsAnalysis'} = [] unless defined $self->{'alignmentChainsAnalysis'};
  push(@{$self->{'alignmentChainsAnalysis'}}, $alignmentChainsAnalysis);

  $self->{'ctrlflow_adaptor'}->create_rule($createAlignmentChainsJobsAnalysis, $alignmentChainsAnalysis);

  $chainConf->{'logic_name'} = $alignmentChainsAnalysis->logic_name;
  #$self->prepCreateAlignmentChainsJobs($chainConf,$alignmentChainsAnalysis->logic_name);

  unless (defined $self->{'updateMaxAlignmentLengthAfterChainAnalysis'}) {
      
      #
      # creating UpdateMaxAlignmentLengthAfterChain analysis
      #
      $parameters = "{\'method_link\'=>\'$output_method_link_type\'}";
      my $updateMaxAlignmentLengthAfterChainAnalysis = Bio::EnsEMBL::Analysis->new
	(-db_version      => '1',
	 -logic_name      => 'UpdateMaxAlignmentLengthAfterChain',
	 -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength',
	 -parameters      => $parameters);
      
      $self->{'analysis_adaptor'}->store($updateMaxAlignmentLengthAfterChainAnalysis);
      $stats = $updateMaxAlignmentLengthAfterChainAnalysis->stats;
      $stats->hive_capacity(1);
      $stats->update();
      $self->{'updateMaxAlignmentLengthAfterChainAnalysis'} = $updateMaxAlignmentLengthAfterChainAnalysis;
      
  }
  $self->{'ctrlflow_adaptor'}->create_rule($alignmentChainsAnalysis, $self->{'updateMaxAlignmentLengthAfterChainAnalysis'});
  $self->{'dataflow_adaptor'}->create_rule($createAlignmentChainsJobsAnalysis,$self->{'updateMaxAlignmentLengthAfterChainAnalysis'}, 2);

  #Create healthcheck jobs if I don't have any net jobs
  if (!defined $self->{'net_conf_list'}) {
      $self->create_pairwise_healthcheck_analysis($output_method_link_type);
  }

}

sub prepareNetSystem {
  my $self = shift;
  my $netConf = shift;
  my $gdb_suffix = shift;

  return unless($netConf);

  my $stats;

  #allow 'query_collection_name' or 'reference_collection_name'
  if ($netConf->{'reference_collection_name'} && !$netConf->{'query_collection_name'}) {
      $netConf->{'query_collection_name'} = $netConf->{'reference_collection_name'};
  }
  
  #allow 'target_collection_name' or 'non_reference_collection_name'
  if ($netConf->{'non_reference_collection_name'} && !$netConf->{'target_collection_name'}) {
      $netConf->{'target_collection_name'} = $netConf->{'non_reference_collection_name'};
  }


  #
  # createAlignmentNetsJobs Analysis
  #
  my $sql = "INSERT ignore into method_link SET method_link_id=?, type=?";
  my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
  my ($input_method_link_id, $input_method_link_type) = @{$netConf->{'input_method_link'}};
  $sth->execute($input_method_link_id, $input_method_link_type);
  my ($output_method_link_id, $output_method_link_type) = @{$netConf->{'output_method_link'}};
  $sth->execute($output_method_link_id, $output_method_link_type);
  $sth->finish;

  #
  # Create setInternalIds analysis if required
  #
  my $setInternalIdsAnalysis;
  if ($self->{'set_internal_ids'}) {
     $setInternalIdsAnalysis = $self->create_set_internal_ids_analysis($output_method_link_type, $netConf);
     $self->{'ctrlflow_adaptor'}->create_rule($self->{'updateMaxAlignmentLengthAfterChainAnalysis'}, $setInternalIdsAnalysis); 
  } 

  my $createAlignmentNetsJobsAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateAlignmentNetsJobs',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateAlignmentNetsJobs',
      -parameters      => ""
    );
  $self->{'analysis_adaptor'}->store($createAlignmentNetsJobsAnalysis);
  $stats = $createAlignmentNetsJobsAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->update();
  $self->{'createAlignmentNetsJobsAnalysis'} = $createAlignmentNetsJobsAnalysis;

  if ($self->{'set_internal_ids'}) {
     $self->{'ctrlflow_adaptor'}->create_rule($setInternalIdsAnalysis, $createAlignmentNetsJobsAnalysis);
  }

  #Iterate through all of the created chain jobs & add them as a blocker
  foreach my $alignmentChainsAnalysis (@{$self->{'alignmentChainsAnalysis'}}) {
      $self->{'ctrlflow_adaptor'}->create_rule($alignmentChainsAnalysis, $createAlignmentNetsJobsAnalysis);
  }

  #
  # AlignmentNets Analysis
  #
  my $max_gap = $netConf->{'max_gap'};

	my @parameters_array = (
		'input_method_link', $input_method_link_type,
		'output_method_link', $output_method_link_type,
		'max_gap', $max_gap,
	);
	push(@parameters_array, ('bin_dir', $netConf->{'bin_dir'})) if defined $netConf->{'bin_dir'};
	my $parameters = generate_paramaters_string(@parameters_array);

  my $alignmentNetsAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'AlignmentNets-'.$gdb_suffix,
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentNets',
      -parameters      => $parameters
    );
  $self->{'analysis_adaptor'}->store($alignmentNetsAnalysis);
  $stats = $alignmentNetsAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(10);
  $stats->update();
  $self->{'alignmentNetsAnalysis'} = $alignmentNetsAnalysis;

  $self->{'ctrlflow_adaptor'}->create_rule($createAlignmentNetsJobsAnalysis, $alignmentNetsAnalysis);

  $self->prepCreateAlignmentNetsJobs($netConf,$alignmentNetsAnalysis->logic_name);

  unless (defined $self->{'updateMaxAlignmentLengthAfterNetAnalysis'}) {

    #
    # creating UpdateMaxAlignmentLengthAfterNet analysis
    #
    $parameters = "{\'method_link\'=>\'$output_method_link_type\'}";
    my $updateMaxAlignmentLengthAfterNetAnalysis = Bio::EnsEMBL::Analysis->new
      (-db_version      => '1',
       -logic_name      => 'UpdateMaxAlignmentLengthAfterNet',
       -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength',
       -parameters      => $parameters);

    $self->{'analysis_adaptor'}->store($updateMaxAlignmentLengthAfterNetAnalysis);
    $stats = $updateMaxAlignmentLengthAfterNetAnalysis->stats;
    $stats->hive_capacity(1);
    $stats->update();
    $self->{'updateMaxAlignmentLengthAfterNetAnalysis'} = $updateMaxAlignmentLengthAfterNetAnalysis;

}

  $self->{'ctrlflow_adaptor'}->create_rule($alignmentNetsAnalysis,$self->{'updateMaxAlignmentLengthAfterNetAnalysis'});
  $self->{'dataflow_adaptor'}->create_rule($createAlignmentNetsJobsAnalysis,$self->{'updateMaxAlignmentLengthAfterNetAnalysis'}, 2);

  #
  #creating FilterStack analysis
  #
  if (defined $netConf->{'filter_stack'} && ($netConf->{'filter_stack'} == 1)) {
      my $query_collection_name = $netConf->{'query_collection_name'};
      my $target_collection_name = $netConf->{'target_collection_name'};
      my $gdb_id1 = $self->{'chunkCollectionHash'}->{$query_collection_name}->{'genome_db_id'};
      my $gdb_id2 = $self->{'chunkCollectionHash'}->{$target_collection_name}->{'genome_db_id'};
      my $height = $netConf->{'height'};
      my $parameters = "{\'method_link\'=>\'$output_method_link_type\',\'query_genome_db_id\'=>\'$gdb_id1\',\'target_genome_db_id\'=>\'$gdb_id2\',\'height\'=>\'$height\'}";
      my $filterStackAnalysis = Bio::EnsEMBL::Analysis->new
	(-db_version      => '1',
	 -logic_name      => 'FilterStack',
	 -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::FilterStack',
	 -parameters      => $parameters);
      
      $self->{'analysis_adaptor'}->store($filterStackAnalysis);
      $stats = $filterStackAnalysis->stats;
      $stats->hive_capacity(1);
      $stats->update();
      $self->{'filterStackAnalysis'} = $filterStackAnalysis; 

      $self->createFilterStackJob($target_collection_name);

      $self->{'ctrlflow_adaptor'}->create_rule($self->{'updateMaxAlignmentLengthAfterNetAnalysis'}, $filterStackAnalysis);

      #
      # creating UpdateMaxAlignmentLengthAfterStack analysis
      #
      $parameters = "{\'method_link\'=>\'$output_method_link_type\'}";
      my $updateMaxAlignmentLengthAfterStackAnalysis = Bio::EnsEMBL::Analysis->new
	(-db_version      => '1',
	 -logic_name      => 'UpdateMaxAlignmentLengthAfterStack',
	 -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength',
	 -parameters      => $parameters);
      
      $self->{'analysis_adaptor'}->store($updateMaxAlignmentLengthAfterStackAnalysis);
      $stats = $updateMaxAlignmentLengthAfterStackAnalysis->stats;
      $stats->hive_capacity(1);
      $stats->update();
      $self->{'updateMaxAlignmentLengthAfterStackAnalysis'} = $updateMaxAlignmentLengthAfterStackAnalysis;
      
      $self->{'ctrlflow_adaptor'}->create_rule($self->{'filterStackAnalysis'}, $updateMaxAlignmentLengthAfterStackAnalysis);
      $self->createUpdateMaxAlignmentLengthAfterStackJob($gdb_id1, $gdb_id2); 
  }

  #Create healthcheck jobs
  $self->create_pairwise_healthcheck_analysis($output_method_link_type);
}

sub create_set_internal_ids_analysis {
    my ($self, $output_method_link_type, $netConf) = @_;
    
    my $setInternalIdsAnalysis = Bio::EnsEMBL::Analysis->new(
       -logic_name      => 'SetInternalIds',
       -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SetInternalIds',
     );

    $self->{'analysis_adaptor'}->store($setInternalIdsAnalysis);
    my $stats = $setInternalIdsAnalysis->stats;
    $stats->batch_size(1);
    $stats->hive_capacity(1);
    $stats->status('BLOCKED');
    $stats->update();
    $self->{'setInternalIdsAnalysis'} = $setInternalIdsAnalysis;

    my $query_collection_name = $netConf->{'query_collection_name'};
    my $target_collection_name = $netConf->{'target_collection_name'};
    my $gdb_id1 = $self->{'chunkCollectionHash'}->{$query_collection_name}->{'genome_db_id'};
    my $gdb_id2 = $self->{'chunkCollectionHash'}->{$target_collection_name}->{'genome_db_id'};
    
    my $input_id = "\'method_link_type\'=>\'$output_method_link_type\',\'genome_db_ids\'=>\'[$gdb_id1, $gdb_id2]\'";

    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
            -input_id       => "{$input_id}",
            -analysis       => $setInternalIdsAnalysis
    );

    return $setInternalIdsAnalysis;
}

 sub create_pairwise_healthcheck_analysis {
     my ($self, $output_method_link_type) = @_;

     my $pairwise_healthcheck_analysis = Bio::EnsEMBL::Analysis->new(
       -logic_name      => 'PairwiseHealthCheck',
       -module          => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
     );

     $self->{'analysis_adaptor'}->store($pairwise_healthcheck_analysis);
      my $stats = $pairwise_healthcheck_analysis->stats;
      $stats->batch_size(1);
      $stats->hive_capacity(1);
      $stats->status('BLOCKED');
      $stats->update();

     #Create healthcheck analysis_jobs

     #pairwise_gabs healthcheck
     my $input_id = "test=>'pairwise_gabs',";

     #Use parameters defined in config file if they exist or create default
     #ones based on the genome_db_ids in the DNA_COLLECTION and the
     #$output_method_link_type variable
     if (defined $healthcheck_conf{'pairwise_gabs'}) {
	 $input_id .= $healthcheck_conf{'pairwise_gabs'};
     } else {
	 my $params = "";
	 $params .= "method_link_type=>\'$output_method_link_type\',";
	 $params .= "genome_db_ids=>'[";

	 $params .= join ",", map $_->{'genome_db_id'}, values %{$self->{'dna_collection_conf_selected_hash'}};

	 $params .= "]'";
	 $input_id .= "params=>{$params}";
     }
     if (defined $healthcheck_conf{'hc_output_dir'}) {
	 $input_id .= ",hc_output_dir=>\'" . $healthcheck_conf{'hc_output_dir'} . "\'";
     }
     $input_id = "{$input_id}";
     
     Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
 	   -input_id       => $input_id,
 	   -analysis       => $pairwise_healthcheck_analysis
           );

     #compare_to_previous_db healthcheck
     $input_id = "test=>'compare_to_previous_db',";

     #Use parameters defined in config file if they exist or create default
     #ones based on the genome_db_ids in the DNA_COLLECTION, the
     #$output_method_link_type variable and the ens-livemirror database
     if (defined $healthcheck_conf{'compare_to_previous_db'}) {
	 $input_id .= $healthcheck_conf{'compare_to_previous_db'};
     } else {
	 my $params = "";

	 #If have specifically defined previous_db_url in config file.
	 if (defined $healthcheck_conf{'previous_db_url'}) {
	     $params .= "previous_db_url=>\'" . $healthcheck_conf{'previous_db_url'} . "\',";
	 } else {
	     #Use default previous_db_url
	     $params .= "previous_db_url=>\'mysql://ensro\@ens-livemirror\',";
	     #$params .= "previous_db_url=>\'mysql://anonymous\@ensembldb.ensembl.org\',";
	 }
	 $params .= "method_link_type=>\'$output_method_link_type\',";
	 
	 $params .= "current_genome_db_ids=>'[";
	 $params .= join ",", map $_->{'genome_db_id'}, values %{$self->{'dna_collection_conf_selected_hash'}};
	 $params .= "]'";
	 $input_id .= "params=>{$params}";
     }
     if (defined $healthcheck_conf{'hc_output_dir'}) {
	 $input_id .= ",hc_output_dir=>\'" . $healthcheck_conf{'hc_output_dir'} . "\'";
     }
     
     $input_id = "{$input_id}";
     
     Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
 	   -input_id       => $input_id,
 	   -analysis       => $pairwise_healthcheck_analysis
     );


     #Create control flow rule to run after last analysis. Need to hard code
     #these for now since we don't have a "do last" analysis control rule.
     if (defined $self->{'updateMaxAlignmentLengthAfterNetAnalysis'}) {

	 $self->{'ctrlflow_adaptor'}->create_rule($self->{'updateMaxAlignmentLengthAfterNetAnalysis'}, $pairwise_healthcheck_analysis);
     } else {
	 #After Chaining (self-self blastz)
	 $self->{'ctrlflow_adaptor'}->create_rule($self->{'updateMaxAlignmentLengthAfterChainAnalysis'}, $pairwise_healthcheck_analysis);
     }
 }

sub storeMaskingOptions
{
  my $self = shift;
  my $dnaCollectionConf = shift;

  my $masking_options_file = $dnaCollectionConf->{'masking_options_file'};
  if (defined $masking_options_file && ! -e $masking_options_file) {
    print("\n__ERROR__\n");
    print("masking_options_file $masking_options_file does not exist\n");
    exit(5);
  }

  my $options_string = "";
  if (defined $masking_options_file) {
    my $options_hash_ref = do($masking_options_file);

    return unless($options_hash_ref);

    $options_string = "{\n";
    foreach my $key (keys %{$options_hash_ref}) {
      $options_string .= "'$key'=>'" . $options_hash_ref->{$key} . "',\n";
    }
    $options_string .= "}";
  } else {
    $options_string = $dnaCollectionConf->{'masking_options'};
    if (!eval($options_string) or $options_string !~ /^\{/) {
      throw("DNA_COLLECTION (".$dnaCollectionConf->{'collection_name'}.
          ") -> masking_options is not properly configured\n".
          "This value must be a string representing a hash!");
    }
  }

  $dnaCollectionConf->{'masking_analysis_data_id'} =
    $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($options_string);

  $dnaCollectionConf->{'masking_options'} = undef;
  $dnaCollectionConf->{'masking_options_file'} = undef;
}

sub createChunkAndGroupDnaJobs
{
  my $self = shift;
  my $dnaCollectionConf = shift;

  if($dnaCollectionConf->{'collection_name'}) {
    my $collection_name = $dnaCollectionConf->{'collection_name'};
    $self->{'chunkCollectionHash'}->{$collection_name} = $dnaCollectionConf;
  }

  my $input_id = "{";
  my @keys = keys %{$dnaCollectionConf};
  foreach my $key (@keys) {
    next unless(defined($dnaCollectionConf->{$key}));
    print("    ",$key," : ", $dnaCollectionConf->{$key}, "\n");
    $input_id .= "'$key'=>'" . $dnaCollectionConf->{$key} . "',";
  }
  $input_id .= "}";

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
      (-input_id       => $input_id,
       -analysis       => $self->{'noChunkAndGroupDnaAnalysis'},
       -input_job_id   => 0);
}

sub create_dump_nib_job
{
  my $self = shift;
  my $collection_name = shift;
  
  my $input_id = "{\'dna_collection_name\'=>\'$collection_name\'}";

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $self->{'dumpLargeNibForChainsAnalysis'},
        -input_job_id   => 0
        );
  
}

sub prepCreateAlignmentChainsJobs {
  my $self = shift;
  my $chainConf = shift;

  return unless($chainConf);

  my $query_collection_name = $chainConf->{'query_collection_name'};
  my $target_collection_name = $chainConf->{'target_collection_name'};
  my $gdb_id1 = $self->{'chunkCollectionHash'}->{$query_collection_name}->{'genome_db_id'};
  my $gdb_id2 = $self->{'chunkCollectionHash'}->{$target_collection_name}->{'genome_db_id'};
  my $logic_name = $chainConf->{'logic_name'};

  my $input_id = "{\'query_genome_db_id\'=>\'$gdb_id1\',\'target_genome_db_id\'=>\'$gdb_id2\',";
  $input_id .= "\'query_collection_name\'=>\'$query_collection_name\',\'target_collection_name\'=>\'$target_collection_name\',";
  $input_id .= ",\'logic_name\'=>\'$logic_name\'}";

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $self->{'createAlignmentChainsJobsAnalysis'},
        -input_job_id   => 0
        );
}

sub prepCreateAlignmentNetsJobs {
  my $self = shift;
  my $netConf = shift;
  my $logic_name = shift;

  return unless($netConf);

  my $query_collection_name = $netConf->{'query_collection_name'};
  my $target_collection_name = $netConf->{'target_collection_name'};
  my $gdb_id1 = $self->{'chunkCollectionHash'}->{$query_collection_name}->{'genome_db_id'};
  my $gdb_id2 = $self->{'chunkCollectionHash'}->{$target_collection_name}->{'genome_db_id'};
  my ($input_method_link_id, $input_method_link_type) = @{$netConf->{'input_method_link'}};

  my $input_id = "{\'method_link\'=>\'$input_method_link_type\'";
  $input_id .= ",\'query_genome_db_id\'=>\'$gdb_id1\',\'target_genome_db_id\'=>\'$gdb_id2\',";
  $input_id .= "\'collection_name\'=>\'$query_collection_name\'";
  $input_id .= ",\'logic_name\'=>\'$logic_name\'}";

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $self->{'createAlignmentNetsJobsAnalysis'},
        -input_job_id   => 0
        );
}

sub createFilterStackJob {
    my $self = shift;
    my $collection_name = shift;

    my $input_id = "{\'collection_name\'=>\'$collection_name\'}";
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $self->{'filterStackAnalysis'},
        -input_job_id   => 0
        );
}

sub createUpdateMaxAlignmentLengthAfterStackJob {
    my $self = shift;
    my $query_genome_db_id = shift;
    my $target_genome_db_id = shift;

    my $input_id = "{\'query_genome_db_id\' => \'" . $query_genome_db_id . "\',\'target_genome_db_id\' => \'" . $target_genome_db_id . "\'}";
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $self->{'updateMaxAlignmentLengthAfterStackAnalysis'},
        -input_job_id   => 0
        );
}

sub generate_paramaters_string {
	my @raw_params = @_;
	my $length = scalar(@raw_params);
	if($length%2 != 0) {
		die("Expected an even number of parameters but was given ${length}");
	}
	my @params;
	for(my $i=0; $i<$length; $i=$i+2) {
		my @vals = map {"'${_}'"} @raw_params[$i,$i+1];
		push(@params, join('=>', @vals));
	}
	return '{'.join(',',@params).'}';
}

1;

