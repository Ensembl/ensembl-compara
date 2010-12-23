#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SimpleNets;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->no_version_check(1);

srand();

my ($conf_file);
my (%hiveConf,
    %comparaConf,
    %alignerConf,
    %chainConf,
    %netConf,
    %collectionConf_by_name);


# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};


GetOptions('conf=s'   => \$conf_file);

&parse_conf($conf_file);

my $COMPARA_DB = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%comparaConf);
my $HIVE_DB = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $COMPARA_DB->dbc);

if(%hiveConf) {
  if(defined($hiveConf{hive_output_dir})) {
    if ($hiveConf{hive_output_dir} ne "" and not -d $hiveConf{hive_output_dir}) {
      die("\nERROR!! hive_output_dir doesn't exist, can't configure\n  ", $hiveConf{hive_output_dir} , "\n");
    }
    $COMPARA_DB->get_MetaContainer->delete_key('hive_output_dir');
    $COMPARA_DB->get_MetaContainer->store_key_value('hive_output_dir', $hiveConf{hive_output_dir});
  }
}

my $lastAnalysis = &prepareChainSystem;
&prepareNetSystem($lastAnalysis);

exit(0);


#######################
#
# subroutines
#

sub parse_conf {
  my $conf_file = shift;

  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk

    my $conf_list = do $conf_file;
    if ($@) {
      die "Your config file is not valid perl: $@\n";
    }

    my %elements;

    foreach my $confPtr (@$conf_list) {
      my $type = $confPtr->{TYPE};
      delete $confPtr->{TYPE};
      $elements{$type} = 1;

      if($type eq 'COMPARA') {
        %comparaConf = %{$confPtr};
      }
      elsif($type eq 'HIVE') {
        %hiveConf = %{$confPtr};
      }
      elsif($type eq 'DNA_COLLECTION') {
        foreach my $k (qw(collection_name genome_db_id)) {
          if (not exists $confPtr->{$k}) {
            die "'$k' must be defined in DNA_COLLECTION\n";
          }
        }
        $collectionConf_by_name{$confPtr->{collection_name}} = $confPtr;
      } 
      elsif ($type eq 'PAIR_ALIGNER') {
        foreach my $k (qw(method_link)) {
          if (not exists $confPtr->{$k}) {
            die "'$k' must be defined in PAIR_ALIGNER config\n";
          }
        }
        %alignerConf = %{$confPtr};

      } 
      elsif($type eq 'CHAIN_CONFIG') {
        foreach my $k (qw(input_method_link_type 
                          method_link 
                          query_collection_name 
                          target_collection_name)) {
          if (not exists $confPtr->{$k}) {
            die "'$k' must be defined in CHAIN_CONFIG\n";
          }
        }
        %chainConf = %{$confPtr};
      } 
      elsif($type eq 'NET_CONFIG') {
        foreach my $k (qw(input_method_link_type
                          method_link 
                          query_collection_name 
                          target_collection_name)) {
          if (not exists $confPtr->{$k}) {
            die "'$k' must be defined in NET_CONFIG\n";
          }
        }
        %netConf = %{$confPtr};

        if (exists $netConf{net_method} and 
            not Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SimpleNets
              ->SUPPORTED_METHOD($netConf{net_method})) {
          die("Method '" . $netConf{net_method} . "' is not supported by SimpleNets"); 
        }
      }
    }
    
    # sanity checks:
    # 0. all config elements are present
    # 1. chain and net collection names should appear in DNA_COLLECTION config
    # 2. chain input method link should match aligner method link
    # 3. net input method link should match chain output method link
    
    foreach my $name (qw(COMPARA HIVE PAIR_ALIGNER DNA_COLLECTION CHAIN_CONFIG NET_CONFIG)) {  
      if (not exists($elements{$name})) {
        &error("Entry '$name' is missing from config");
      }
    }
    
    my $qname = $chainConf{query_collection_name};
    my $tname = $chainConf{target_collection_name};
    if (not exists $collectionConf_by_name{$qname} or
        not exists $collectionConf_by_name{$tname}) {
      &error("In CHAIN_CONFIG entry, one of query/target collection names is not recognised");
    }

    $qname = $netConf{query_collection_name};
    $tname = $netConf{target_collection_name};
    if (not exists $collectionConf_by_name{$qname} or
        not exists $collectionConf_by_name{$tname}) {
      &error("In NET_CONFIG entry, one of query/target collection names is not recognised");
    }

    if ($chainConf{input_method_link_type} ne $alignerConf{method_link}->[1]) {
      &error("Chain input_method_link_type does not match alignment method_link type");
    }
    if ($netConf{input_method_link_type} ne $chainConf{method_link}->[1]) {
      &error("Net input_method_link_type does not match chain method_link type");
    }
  } else {
    &error("You must supply a config file");
  }
}

#####################################################################################

sub prepareChainSystem {
  #
  # pull out all necessary parameters
  #
  my $input_method_link_type = $chainConf{input_method_link_type};
  my $input_method_link_id = $alignerConf{method_link}->[1];
  my ($output_method_link_id, $output_method_link_type) = @{$chainConf{method_link}};
  my $query_collection_name = $chainConf{query_collection_name};
  my $target_collection_name = $chainConf{target_collection_name};

  my $qy_gdb_id = $collectionConf_by_name{$query_collection_name}->{genome_db_id};
  my $tg_gdb_id = $collectionConf_by_name{$target_collection_name}->{genome_db_id};

  my $qy_gdb = $COMPARA_DB->get_GenomeDBAdaptor->fetch_by_dbID($qy_gdb_id);
  my $tg_gdb = $COMPARA_DB->get_GenomeDBAdaptor->fetch_by_dbID($tg_gdb_id);

  &error("Could not fetch query or target genome dbs (ids $qy_gdb_id, $tg_gdb_id")
      if not defined $qy_gdb or not defined $tg_gdb;

  my $max_gap = $chainConf{max_gap}; 
  $max_gap = 50 if not defined $max_gap;
  my $output_group_type = $chainConf{output_group_type}; 
  $output_group_type = "chain" if not defined $output_group_type;
  my $max_workers = $chainConf{max_parallel_workers};
  $max_workers = 100 if not $max_workers;
  
  my $chunkAndGroupDnaAnalysis = $HIVE_DB->get_AnalysisAdaptor()->fetch_by_logic_name('ChunkAndGroupDna');
  &error("You have no DnaChunks in your database; looks like you have not run the raw Blastz pipeline")
      if not defined $chunkAndGroupDnaAnalysis;

  # 
  # insert method link entries, if necessary
  #
  my $sql = "INSERT ignore into method_link SET method_link_id=?, type=?";
  my $sth = $COMPARA_DB->dbc->prepare($sql);
  $sth->execute($output_method_link_id, $output_method_link_type);
  $sth->finish;

  #
  # insert method_link_species_set
  #
  my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $mlss->method_link_type($output_method_link_type);
  $mlss->species_set([$qy_gdb, $tg_gdb]);
  $COMPARA_DB->get_MethodLinkSpeciesSetAdaptor->store($mlss);

  my $stats;
  #
  # create chain jobs
  #
  
  my $createAlignmentChainsJobsAnalysis = Bio::EnsEMBL::Analysis->new
      (-db_version      => '1',
       -logic_name      => 'CreateAlignmentChainsJobs',
       -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateAlignmentChainsJobs',
       -parameters      => &make_parameters_string(method_link => $input_method_link_type)
       );
  $HIVE_DB->get_AnalysisAdaptor()->store($createAlignmentChainsJobsAnalysis);
  $stats = $createAlignmentChainsJobsAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->update();

  #
  # calculation of alignment chains
  #
  
  my $alignmentChainsAnalysis = Bio::EnsEMBL::Analysis->new
      (-db_version      => '1',
       -logic_name      => 'AlignmentChains',
       -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentChains',
       -parameters      => &make_parameters_string(input_method_link => $input_method_link_type,
                                                   output_method_link => $output_method_link_type,
                                                   max_gap => $max_gap,
                                                   output_group_type => $output_group_type),
       );

  $HIVE_DB->get_AnalysisAdaptor()->store($alignmentChainsAnalysis);
  $stats = $alignmentChainsAnalysis->stats;
  $stats->batch_size(100);
  $stats->hive_capacity($max_workers);
  $stats->update();

  #
  # update max alignment length after chains
  #
  my $updateMaxAlignmentLengthAfterChainAnalysis = Bio::EnsEMBL::Analysis->new
      (-db_version      => '1',
       -logic_name      => 'UpdateMaxAlignmentLengthAfterChain',
       -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength',
       -parameters      => &make_parameters_string(method_link => $output_method_link_type));
  
  $HIVE_DB->get_AnalysisAdaptor()->store($updateMaxAlignmentLengthAfterChainAnalysis);
  $stats = $updateMaxAlignmentLengthAfterChainAnalysis->stats;
  $stats->hive_capacity(1);
  $stats->update();

  #
  # create rules
  #
  my $dataflowRuleDBA = $HIVE_DB->get_DataflowRuleAdaptor;
  my $ctrlRuleDBA = $HIVE_DB->get_AnalysisCtrlRuleAdaptor;
  $ctrlRuleDBA->create_rule($chunkAndGroupDnaAnalysis, $createAlignmentChainsJobsAnalysis);
  $ctrlRuleDBA->create_rule($createAlignmentChainsJobsAnalysis, $alignmentChainsAnalysis);
  $ctrlRuleDBA->create_rule($alignmentChainsAnalysis, $updateMaxAlignmentLengthAfterChainAnalysis);
  $dataflowRuleDBA->create_rule($createAlignmentChainsJobsAnalysis,$updateMaxAlignmentLengthAfterChainAnalysis, 2);

  #
  # finally, create the CreateAlignmentChains job itself
  #

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob 
      (-input_id => &make_parameters_string(query_genome_db_id => $qy_gdb_id,
                                            target_genome_db_id => $tg_gdb_id,
                                            query_collection_name => $query_collection_name,
                                            target_collection_name => $target_collection_name),
       -analysis       => $createAlignmentChainsJobsAnalysis,
      );


  return $updateMaxAlignmentLengthAfterChainAnalysis;
}

#####################################################################################


sub prepareNetSystem {
  my $last_analysis = shift;
  #
  # obtain all necessary config variables
  #
  my $input_method_link_type = $netConf{input_method_link_type};
  my $input_method_link_id = $chainConf{method_link}->[1];
  my ($output_method_link_id, $output_method_link_type) = @{$netConf{method_link}};
  my $query_collection_name = $netConf{query_collection_name};
  my $target_collection_name = $netConf{target_collection_name};

  my $qy_gdb_id = $collectionConf_by_name{$query_collection_name}->{genome_db_id};
  my $tg_gdb_id = $collectionConf_by_name{$target_collection_name}->{genome_db_id};

  my $qy_gdb = $COMPARA_DB->get_GenomeDBAdaptor->fetch_by_dbID($qy_gdb_id);
  my $tg_gdb = $COMPARA_DB->get_GenomeDBAdaptor->fetch_by_dbID($tg_gdb_id);

  &error("Could not fetch query or target genome dbs (ids $qy_gdb_id, $tg_gdb_id")
      if not defined $qy_gdb or not defined $tg_gdb;

  my $net_method = $netConf{net_method};
  $net_method = "ContigAwareNet" if not defined $net_method;
  my $max_gap = $netConf{max_gap}; 
  $max_gap = 50 if not defined $max_gap;
  my $input_group_type = $netConf{input_group_type}; 
  $input_group_type = "chain" if not defined $input_group_type;
  my $output_group_type = $netConf{input_group_type}; 
  $output_group_type = "chain" if not defined $output_group_type;
  my $max_workers = $netConf{max_parallel_workers};
  $max_workers = 100 if not $max_workers;

  #
  # Insert method link entry
  # 
  my $sql = "INSERT ignore into method_link SET method_link_id=?, type=?";
  my $sth = $COMPARA_DB->dbc->prepare($sql);
  $sth->execute($output_method_link_id, $output_method_link_type);
  $sth->finish;

  #
  # insert method_link_species_set
  #
  my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $mlss->method_link_type($output_method_link_type);
  $mlss->species_set([$qy_gdb, $tg_gdb]);
  $COMPARA_DB->get_MethodLinkSpeciesSetAdaptor->store($mlss);

  my $stats;

  #
  # calculate alignment nets
  #
  my $alignment_net_logic = 'Net-' . $net_method; 
  my $alignmentNetsAnalysis = Bio::EnsEMBL::Analysis
      ->new(
            -db_version      => '1',
            -logic_name      => $alignment_net_logic,
            -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SimpleNets',
            -parameters      => &make_parameters_string(input_method_link => $input_method_link_type,
                                                        output_method_link => $output_method_link_type,
                                                        input_group_type => $input_group_type,
                                                        output_group_type => $output_group_type,
                                                        max_gap => $max_gap,
                                                        net_method => $net_method)
            );
  $HIVE_DB->get_AnalysisAdaptor()->store($alignmentNetsAnalysis);
  $stats = $alignmentNetsAnalysis->stats;
  $stats->batch_size(100);
  $stats->hive_capacity($max_workers);
  $stats->update();

  #
  # create alignment nets jobs
  #
  my $createAlignmentNetsJobsAnalysis = Bio::EnsEMBL::Analysis
      ->new(
            -db_version      => '1',
            -logic_name      => 'CreateAlignmentNetsJobs',
            -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateSimpleNetsJobs',
            -parameters      => &make_parameters_string(input_method_link => $input_method_link_type,
                                                        logic_name        => $alignment_net_logic),
            );
  $HIVE_DB->get_AnalysisAdaptor()->store($createAlignmentNetsJobsAnalysis);
  $stats = $createAlignmentNetsJobsAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->update();

  #
  # update max alignment length after nets
  #
  my $updateMaxAlignmentLengthAfterNetAnalysis = Bio::EnsEMBL::Analysis->new
      (-db_version      => '1',
       -logic_name      => 'UpdateMaxAlignmentLengthAfterNet',
       -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength',
       -parameters      => &make_parameters_string(method_link => $output_method_link_type)
       );
  
  $HIVE_DB->get_AnalysisAdaptor()->store($updateMaxAlignmentLengthAfterNetAnalysis);
  $stats = $updateMaxAlignmentLengthAfterNetAnalysis->stats;
  $stats->hive_capacity(1);
  $stats->update();

  #
  # Create the control rules
  #

  my $dataflowRuleDBA = $HIVE_DB->get_DataflowRuleAdaptor;
  my $ctrlRuleDBA = $HIVE_DB->get_AnalysisCtrlRuleAdaptor;
  $ctrlRuleDBA->create_rule($last_analysis, $createAlignmentNetsJobsAnalysis);
  $ctrlRuleDBA->create_rule($createAlignmentNetsJobsAnalysis, $alignmentNetsAnalysis);
  $ctrlRuleDBA->create_rule($alignmentNetsAnalysis,$updateMaxAlignmentLengthAfterNetAnalysis);
  $dataflowRuleDBA->create_rule($createAlignmentNetsJobsAnalysis,$updateMaxAlignmentLengthAfterNetAnalysis);

  #
  # Finally, create the CreateAlignmentNets job itself
  #
  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
      (-input_id => &make_parameters_string(query_genome_db_id => $qy_gdb_id,
                                            target_genome_db_id => $tg_gdb_id),
       -analysis       => $createAlignmentNetsJobsAnalysis,
       );
}




sub make_parameters_string {
  my (%pairs) = @_;

  my $string = "{";
  my @terms;
  foreach my $k (keys %pairs) {
    my $val = $pairs{$k};

    my $left = "\'$k\'";
    my $right = "\'$val\'";
    my $term = "$left => $right";
    push @terms, $term;
  }

  $string .= join(",", @terms);

  $string .= "}";
  return $string;
}

sub error {
  my ($str) = @_;

  print STDERR "Config error: $str\n";
  exit(1);
}


1;

