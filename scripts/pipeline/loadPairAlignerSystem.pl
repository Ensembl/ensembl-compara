#!/software/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::DBLoader;

my $conf_file;
my $verbose;
my $help;

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};


GetOptions('help'     => \$help,
           'conf=s'   => \$conf_file,
           'v' => \$verbose);

if ($help) { usage(); }

my %hive_params;
my %engine_params;
my %compara_conf;
$compara_conf{'-port'} = 3306;

#list of compara tables to be changed to InnoDB
my @dna_pipeline_tables = qw(genomic_align_block genomic_align genomic_align_group genomic_align_tree sequence dnafrag_region constrained_element conservation_score);

Bio::EnsEMBL::Registry->no_version_check(1);

$self->parse_conf($conf_file);

unless(defined($compara_conf{'-host'}) and defined($compara_conf{'-user'}) and defined($compara_conf{'-dbname'})) {
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage(); 
}

$self->{'comparaDBA'}       = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf);
$self->{'hiveDBA'}          = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);
$self->{'analysis_adaptor'} = $self->{'hiveDBA'}->get_AnalysisAdaptor;
$self->{'dataflow_adaptor'} = $self->{'hiveDBA'}->get_DataflowRuleAdaptor;
$self->{'ctrlflow_adaptor'} = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;

if(%hive_params) {
  if(defined($hive_params{'hive_output_dir'}) && $hive_params{'hive_output_dir'} ne "") {
    die("\nERROR!! hive_output_dir doesn't exist, can't configure\n  ", $hive_params{'hive_output_dir'} , "\n")
      unless(-d $hive_params{'hive_output_dir'});
    $self->{'comparaDBA'}->get_MetaContainer->delete_key('hive_output_dir');
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('hive_output_dir', $hive_params{'hive_output_dir'});
  }
}

if (%engine_params) {
    if (defined ($engine_params{'dna_pipeline'}) && $engine_params{'dna_pipeline'} ne "") {
	#Change tables to ENGINE
	my $engine = $engine_params{'dna_pipeline'};
	if (lc($engine) ne "innodb" && lc($engine) ne "myisam") {
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

$self->preparePairAlignerSystem;

$self->{'dna_collection_conf_selected_hash'} = {};
foreach my $pairAlignerConf (@{$self->{'pair_aligner_conf_list'}}) {
  my $ref_dna_collection_name    = $pairAlignerConf->{'reference_collection_name'};
  my $nonref_dna_collection_name = $pairAlignerConf->{'non_reference_collection_name'};
  print("filtering DNA_COLLECTIONs used for PairAligner('$ref_dna_collection_name','$nonref_dna_collection_name')\n");

  $self->{'dna_collection_conf_selected_hash'}{$ref_dna_collection_name}    = $self->{'dna_collection_conf_full_hash'}{$ref_dna_collection_name}; 
  $self->{'dna_collection_conf_selected_hash'}{$nonref_dna_collection_name} = $self->{'dna_collection_conf_full_hash'}{$nonref_dna_collection_name}; 
}

foreach my $dnaCollectionConf (values %{$self->{'dna_collection_conf_selected_hash'}}) {
  my $dna_collection_name = $dnaCollectionConf->{'collection_name'};
  print("creating ChunkAndGroup jobs for '$dna_collection_name'\n");
  $self->storeMaskingOptions($dnaCollectionConf);

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
      -input_id       => $dnaCollectionConf,
      -analysis       => $self->{'chunkAndGroupDnaAnalysis'},
  );

      #Create dataflow rule to create sequence storing jobs on branch 1
  $self->{'dataflow_adaptor'}->create_rule($self->{'chunkAndGroupDnaAnalysis'}, $self->{'storeSequenceAnalysis'},1);
}

foreach my $pairAlignerConf (@{$self->{'pair_aligner_conf_list'}}) {

    my $ref_dna_collection_name    = $pairAlignerConf->{'reference_collection_name'};
    my $nonref_dna_collection_name = $pairAlignerConf->{'non_reference_collection_name'};

    my $gdb_suffix = $self->{'dna_collection_conf_selected_hash'}{$ref_dna_collection_name}{'genome_db_id'}
               .'-'. $self->{'dna_collection_conf_selected_hash'}{$nonref_dna_collection_name}{'genome_db_id'};

  print "createPairAlignerAnalysis($gdb_suffix)\n";
  $self->createPairAlignerAnalysis($pairAlignerConf, $gdb_suffix);
}

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "loadPairAlignerSystem.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates\n";
  print "loadPairAlignerSystem.pl v1.2\n";
  
  exit(1);  
}


sub parse_conf {
  my $self = shift;
  my $conf_file = shift;

  $self->{'genomic_align_conf_list'}  = [];
  $self->{'dna_collection_conf_full_hash'} = {};
  
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
        push @{$self->{'pair_aligner_conf_list'}} , $confPtr;
      }
      elsif($type eq 'DNA_COLLECTION') {
        my $dna_collection_name = $confPtr->{'collection_name'};
        $self->{'dna_collection_conf_full_hash'}{$dna_collection_name} = $confPtr;
    } elsif($type eq 'ENGINE') {
        %engine_params = %{$confPtr};
    }
    }
  }
}


# need to make sure analysis 'SubmitGenome' is in database
# this is a generic analysis of type 'genome_db_id'
# the input_id for this analysis will be a genome_db_id
# the full information to access the genome will be in the compara database

sub preparePairAlignerSystem {
  my $self = shift;

  my $stats;

  #
  # SubmitGenome
  #
  my $submit_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'SubmitGenome',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy'
    );
  $self->{'analysis_adaptor'}->store($submit_analysis);
  $stats = $submit_analysis->stats;
  $stats->batch_size(100);
  $stats->hive_capacity(-1);
  $stats->update();

  #
  # creating ChunkAndGroupDna analysis
  #
  my $chunkAndGroupDnaAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'ChunkAndGroupDna',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ChunkAndGroupDna',
      -parameters      => '{}',
    );
  $self->{'analysis_adaptor'}->store($chunkAndGroupDnaAnalysis);
  $stats = $chunkAndGroupDnaAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1); #unlimited
  $stats->update();
  $self->{'chunkAndGroupDnaAnalysis'} = $chunkAndGroupDnaAnalysis;

  $self->{'ctrlflow_adaptor'}->create_rule($submit_analysis, $chunkAndGroupDnaAnalysis);

  #
  # creating StoreSequence analysis
  #
  my $storeSequenceAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'StoreSequence',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::StoreSequence',
      -parameters      => '{}',
    );
  $self->{'analysis_adaptor'}->store($storeSequenceAnalysis);
  $stats = $storeSequenceAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(100); 
  $stats->update();
  $self->{'storeSequenceAnalysis'} = $storeSequenceAnalysis;

  #
  # creating CreatePairAlignerJobs analysis
  #
  my $createPairAlignerJobsAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreatePairAlignerJobs',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreatePairAlignerJobs',
      -parameters      => '{}',
    );
  $self->{'analysis_adaptor'}->store($createPairAlignerJobsAnalysis);
  $stats = $createPairAlignerJobsAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->update();
  $self->{'createPairAlignerJobsAnalysis'} = $createPairAlignerJobsAnalysis;

  $self->{'ctrlflow_adaptor'}->create_rule($chunkAndGroupDnaAnalysis, $createPairAlignerJobsAnalysis);
  $self->{'ctrlflow_adaptor'}->create_rule($storeSequenceAnalysis, $createPairAlignerJobsAnalysis);
}


sub createPairAlignerAnalysis {
  my $self              = shift;
  my $pair_aligner_conf = shift;  #hash reference
  my $gdb_suffix        = shift;

  print("creating PairAligner jobs\n") if($verbose);

  #allow 'query_collection_name' or 'non_reference_collection_name'
  if ($pair_aligner_conf->{'non_reference_collection_name'} && !$pair_aligner_conf->{'query_collection_name'}) {
      $pair_aligner_conf->{'query_collection_name'} = $pair_aligner_conf->{'non_reference_collection_name'};
  }

  my $query_dnaCollectionConf = $self->{'dna_collection_conf_selected_hash'}{$pair_aligner_conf->{'query_collection_name'}};

  #allow 'target_collection_name' or 'reference_collection_name'
  if ($pair_aligner_conf->{'reference_collection_name'} && !$pair_aligner_conf->{'target_collection_name'}) {
      $pair_aligner_conf->{'target_collection_name'} = $pair_aligner_conf->{'reference_collection_name'};
  }

  my $target_dnaCollectionConf = $self->{'dna_collection_conf_selected_hash'}{$pair_aligner_conf->{'target_collection_name'}};

  if($pair_aligner_conf->{'method_link'}) {
    my ($method_link_id, $method_link_type) = @{$pair_aligner_conf->{'method_link'}};
    my $sql = "INSERT ignore into method_link SET method_link_id=$method_link_id, type='$method_link_type'";
    print("$sql\n");
    $self->{'hiveDBA'}->dbc->do($sql);
        
    #
    # creating MethodLinkSpeciesSet entry
    #
    my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
    $mlss->method_link_type($method_link_type); 
    my $gdb_id1 = $query_dnaCollectionConf->{'genome_db_id'};
    my $gdb_id2 = $target_dnaCollectionConf->{'genome_db_id'};
    printf("create MethodLinkSpeciesSet for genomes %d:%d\n", $gdb_id1, $gdb_id2);
    my $gdb1 = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id1);
    unless (defined $gdb1) {
      print("\n__ERROR__\n");
      print("There is no genomeDB for genome_db_id $gdb_id1\n");
      print("You need to load the genomeDBs first, with comparaLoadGenomes.pl \n");
      exit(2);
    }
    my $gdb2 = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id2);
    unless (defined $gdb2) {
      print("\n__ERROR__\n");
      print("There is no genomeDB for genome_db_id $gdb_id2\n");
      print("You need to load the genomeDBs first, with comparaLoadGenomes.pl \n");
      exit(3);
    }
    if ($gdb1->dbID == $gdb2->dbID) {
      $mlss->species_set([$gdb1]);
    } else {
      $mlss->species_set([$gdb1, $gdb2]);
    }
    $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);
    $self->{'method_link_species_set'} = $mlss;
    $pair_aligner_conf->{'method_link_species_set_id'} = $mlss->dbID;
  }
      
  #
  # creating PairAligner_$gdb_suffix analysis
  #

  my $pairAlignerAnalysis = new Bio::EnsEMBL::Analysis(%{$pair_aligner_conf->{'analysis_template'}});
  my $parameters = $pairAlignerAnalysis->parameters();
  
  #if running blat, need to append dump_loc to blat analysis parameters 
  if ($target_dnaCollectionConf->{'dump_loc'}) {
      my $dump_loc = $target_dnaCollectionConf->{'dump_loc'};
      $parameters =~ s/\}/,dump_loc=>'$dump_loc'\}/;
      $pairAlignerAnalysis->parameters($parameters);
  }

  $pair_aligner_conf->{'logic_name_prefix'} ||= 'PairAligner';

  my $logic_name = $pair_aligner_conf->{'logic_name_prefix'}."-".$gdb_suffix;

  print "logic_name $logic_name\n";
  $pairAlignerAnalysis->logic_name($logic_name);
  $self->{'analysis_adaptor'}->store($pairAlignerAnalysis);
  my $stats = $pairAlignerAnalysis->stats;
  $stats->hive_capacity(200);
  if($pair_aligner_conf->{'max_parallel_workers'}) {
    print "max_parallel_workers: ",$pair_aligner_conf->{'max_parallel_workers'},"\n";
    $stats->hive_capacity($pair_aligner_conf->{'max_parallel_workers'});
  }
  print "hive_capacity: ", $stats->hive_capacity,"\n";
  if($pair_aligner_conf->{'batch_size'}) {
    $stats->batch_size($pair_aligner_conf->{'batch_size'});
  }
  $stats->update();

  #Dump reference dna as overlapping chunks in multi-fasta file
  if ($target_dnaCollectionConf->{'dump_loc'}) { 
 
      my $analysis_parameters = "{'dump_dna'=>1,'dump_min_size'=>1";

      if ($target_dnaCollectionConf->{'dump_nib'}) {   
        $analysis_parameters.=",'dump_nib'=>1,";
      }else {  
        print "\n\nWARNING !\nYou've configured compara to not dump any nib files !!!\n".
         "The analysis will run a lot slower. To dump nib-files change your compara analysis configuration file\n". 
         " and add dump_nib => 1 to the DNA_COLLECTION config-hash of your well-analysed target genome (usually human)\n\n" ; 
        sleep(3);
      } 
      $analysis_parameters.="}";
     
      ## We want to dump the target collection for Blat. Set dump_min_size to 1 to ensure that all the toplevel seq_regions are dumped. 
      # The use of group_set_size in the target collection ensures that short seq_regions are grouped together. 
      my $dumpDnaAnalysis = Bio::EnsEMBL::Analysis->new(
           -module => "Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::DumpDnaCollection",
           -parameters => $analysis_parameters, 
      );
      my $dump_dna_logic_name = "DumpDnaFor".$pair_aligner_conf->{'logic_name_prefix'}."-".$gdb_suffix;

      $dumpDnaAnalysis->logic_name($dump_dna_logic_name);

      $self->{'analysis_adaptor'}->store($dumpDnaAnalysis);

      my $stats = $dumpDnaAnalysis->stats;
      $stats->hive_capacity(1);
      $stats->batch_size(1);
      $stats->update();
      $self->{'dump_dna_analysis'} = $dumpDnaAnalysis;

      if ($target_dnaCollectionConf->{'dump_loc'}) {
          Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
              -input_id       => { 'dna_collection_name' => $pair_aligner_conf->{'target_collection_name'} },
              -analysis       => $self->{'dump_dna_analysis'},
          );
      }

      ## Create new rule: DumpDna before running Blat!!
      $self->{'ctrlflow_adaptor'}->create_rule($self->{'chunkAndGroupDnaAnalysis'}, $dumpDnaAnalysis);
      $self->{'ctrlflow_adaptor'}->create_rule($dumpDnaAnalysis, $pairAlignerAnalysis);
  }

  unless (defined $self->{'updateMaxAlignmentLengthBeforeFDAnalysis'}) {

    #
    # creating UpdateMaxAlignmentLengthBeforeFD analysis
    #

    my $updateMaxAlignmentLengthBeforeFDAnalysis = Bio::EnsEMBL::Analysis->new(
        -db_version      => '1',
        -logic_name      => 'UpdateMaxAlignmentLengthBeforeFD',
        -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength',
        -parameters      => '{}',
    );
    
    $self->{'analysis_adaptor'}->store($updateMaxAlignmentLengthBeforeFDAnalysis);
    my $stats = $updateMaxAlignmentLengthBeforeFDAnalysis->stats;
    $stats->hive_capacity(1);
    $stats->update();
    $self->{'updateMaxAlignmentLengthBeforeFDAnalysis'} = $updateMaxAlignmentLengthBeforeFDAnalysis;


    #
    # create UpdateMaxAlignmentLengthBeforeFD job
    #
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
        -input_id       => '{}',
        -analysis       => $self->{'updateMaxAlignmentLengthBeforeFDAnalysis'},
    );
  }

  $self->{'ctrlflow_adaptor'}->create_rule($pairAlignerAnalysis, $self->{'updateMaxAlignmentLengthBeforeFDAnalysis'});

  #
  # create CreatePairAlignerJobs job
  #
  my $input_id = {
    'pair_aligner'               => $pairAlignerAnalysis->logic_name,
    'query_collection_name'      => $pair_aligner_conf->{'query_collection_name'},
    'target_collection_name'     => $pair_aligner_conf->{'target_collection_name'},
  };
  if($pair_aligner_conf->{'method_link_species_set_id'}) {
    $input_id->{'method_link_species_set_id'} = $pair_aligner_conf->{'method_link_species_set_id'};
  }

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
      -input_id       => $input_id,
      -analysis       => $self->{'createPairAlignerJobsAnalysis'},
  );

  #
  # Creating FilterDuplicates analysis
  #
  # Now done always. If there is no chunking on the query, it will only
  # remove identical matches from each query dnafrag. If there is chunking
  # on the query, then it will remove both identical matches and edge
  # artefacts.

  #
  # creating NonrefFilterDuplicates analysis
  #
  $parameters = "{'method_link_species_set_id'=>".$pair_aligner_conf->{'method_link_species_set_id'};
  
  if (defined $query_dnaCollectionConf->{'chunk_size'} && 
      $query_dnaCollectionConf->{'chunk_size'} > 0) {
      $parameters .= ",'chunk_size'=>".$query_dnaCollectionConf->{'chunk_size'};
  }
  if (defined $query_dnaCollectionConf->{'overlap'} && 
      $query_dnaCollectionConf->{'overlap'} > 0) {
      $parameters .= ",'overlap'=>".$query_dnaCollectionConf->{'overlap'};
  } 
  $parameters .= "}";

  my $nonrefFilterDuplicatesAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'NonrefFilterDuplicates-'.$gdb_suffix,
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::FilterDuplicates',
      -parameters      => $parameters,
  );
  $self->{'analysis_adaptor'}->store($nonrefFilterDuplicatesAnalysis);

  $stats = $nonrefFilterDuplicatesAnalysis->stats;
  $stats->batch_size(5);
  $stats->hive_capacity(50); 
  $stats->status('BLOCKED');
  $stats->update();
  $self->{'nonrefFilterDuplicatesAnalysis'} = $nonrefFilterDuplicatesAnalysis;

  $self->{'ctrlflow_adaptor'}->create_rule($self->{'updateMaxAlignmentLengthBeforeFDAnalysis'}, $nonrefFilterDuplicatesAnalysis);

  unless (defined $self->{'updateMaxAlignmentLengthAfterFDAnalysis'}) {
        
      #
      # creating UpdateMaxAlignmentLengthAfterFD analysis
      #
      
      my $updateMaxAlignmentLengthAfterFDAnalysis = Bio::EnsEMBL::Analysis->new(
          -db_version      => '1',
          -logic_name      => 'UpdateMaxAlignmentLengthAfterFD',
          -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength',
          -parameters      => '{}',
      );
      
      $self->{'analysis_adaptor'}->store($updateMaxAlignmentLengthAfterFDAnalysis);
      my $stats = $updateMaxAlignmentLengthAfterFDAnalysis->stats;
      $stats->hive_capacity(1);
      $stats->update();
      $self->{'updateMaxAlignmentLengthAfterFDAnalysis'} = $updateMaxAlignmentLengthAfterFDAnalysis;
      
      
      #
      # create UpdateMaxAlignmentLengthAfterFD job
      #
      Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
          -input_id       => '{}',
          -analysis       => $self->{'updateMaxAlignmentLengthAfterFDAnalysis'},
      );
  }
  
  $self->{'ctrlflow_adaptor'}->create_rule($nonrefFilterDuplicatesAnalysis,$self->{'updateMaxAlignmentLengthAfterFDAnalysis'});
  
  #
  # create CreateFilterDuplicatesJobs analysis
  #
  unless (defined $self->{'createFilterDuplicatesJobsAnalysis'}) {
      my $createFilterDuplicatesJobsAnalysis = Bio::EnsEMBL::Analysis->new(
          -db_version      => '1',
          -logic_name      => 'CreateFilterDuplicatesJobs',
          -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateFilterDuplicatesJobs',
          -parameters      => '{}',
      );
      $self->{'analysis_adaptor'}->store($createFilterDuplicatesJobsAnalysis);
      $stats = $createFilterDuplicatesJobsAnalysis->stats;
      $stats->batch_size(1);
      if($pair_aligner_conf->{'max_parallel_workers'}) {
          $stats->hive_capacity($pair_aligner_conf->{'max_parallel_workers'});
      }
      $stats->update();
      $self->{'createFilterDuplicatesJobsAnalysis'} = $createFilterDuplicatesJobsAnalysis;
      
      $self->{'ctrlflow_adaptor'}->create_rule($self->{'chunkAndGroupDnaAnalysis'}, $createFilterDuplicatesJobsAnalysis);
  }
  
  #
  # create nonrefCreateFilterDuplicatesJobs job
  #
  $input_id = {
        'logic_name'        => $nonrefFilterDuplicatesAnalysis->logic_name,
        'collection_name'   => $pair_aligner_conf->{'query_collection_name'},
  };
  if ($query_dnaCollectionConf->{'region'}) {
      $input_id->{'region'} = $query_dnaCollectionConf->{'region'};
  }
  
  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
      -input_id       => $input_id,
      -analysis       => $self->{'createFilterDuplicatesJobsAnalysis'},
  );

  #
  # creating RefFilterDuplicates analysis
  #
  $parameters = "{'method_link_species_set_id'=>".$pair_aligner_conf->{'method_link_species_set_id'};
  
  if (defined $target_dnaCollectionConf->{'chunk_size'} && 
      $target_dnaCollectionConf->{'chunk_size'} > 0) {
      $parameters .= ",'chunk_size'=>".$target_dnaCollectionConf->{'chunk_size'};
  }
  if (defined $target_dnaCollectionConf->{'overlap'} && 
      $target_dnaCollectionConf->{'overlap'} > 0) {
      $parameters .= ",'overlap'=>".$target_dnaCollectionConf->{'overlap'};
  } 
  $parameters .= "}";
  
  my $refFilterDuplicatesAnalysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'RefFilterDuplicates-'.$gdb_suffix,
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::FilterDuplicates',
      -parameters      => $parameters,
  );
  $self->{'analysis_adaptor'}->store($refFilterDuplicatesAnalysis);
  $stats = $refFilterDuplicatesAnalysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(200);
  $stats->status('BLOCKED');
  $stats->update();
  $self->{'refFilterDuplicatesAnalysis'} = $refFilterDuplicatesAnalysis;
  
  if (defined $nonrefFilterDuplicatesAnalysis) {
      $self->{'ctrlflow_adaptor'}->create_rule($nonrefFilterDuplicatesAnalysis, $refFilterDuplicatesAnalysis);
  } else {
      $self->{'ctrlflow_adaptor'}->create_rule($pairAlignerAnalysis, $refFilterDuplicatesAnalysis);
  }
  
  unless (defined $self->{'updateMaxAlignmentLengthAfterFDAnalysis'}) {
      
      #
      # creating UpdateMaxAlignmentLengthAfterFD analysis
      #
      
      my $updateMaxAlignmentLengthAfterFDAnalysis = Bio::EnsEMBL::Analysis->new(
          -db_version      => '1',
          -logic_name      => 'UpdateMaxAlignmentLengthAfterFD',
          -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength',
          -parameters      => '{}',
      );
      
      $self->{'analysis_adaptor'}->store($updateMaxAlignmentLengthAfterFDAnalysis);
      my $stats = $updateMaxAlignmentLengthAfterFDAnalysis->stats;
      $stats->hive_capacity(1);
      $stats->update();
      $self->{'updateMaxAlignmentLengthAfterFDAnalysis'} = $updateMaxAlignmentLengthAfterFDAnalysis;
      
      
      #
      # create UpdateMaxAlignmentLengthAfterFD job
      #
      Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
          -input_id       => '{}',
	      -analysis       => $self->{'updateMaxAlignmentLengthAfterFDAnalysis'},
      );
  }
  
  $self->{'ctrlflow_adaptor'}->create_rule($refFilterDuplicatesAnalysis,$self->{'updateMaxAlignmentLengthAfterFDAnalysis'});
  
  #
  # create CreateFilterDuplicatesJobs analysis
  #
  unless (defined $self->{'createFilterDuplicatesJobsAnalysis'}) {
      my $createFilterDuplicatesJobsAnalysis = Bio::EnsEMBL::Analysis->new(
          -db_version      => '1',
          -logic_name      => 'CreateFilterDuplicatesJobs',
          -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateFilterDuplicatesJobs',
          -parameters      => '{}',
      );
      $self->{'analysis_adaptor'}->store($createFilterDuplicatesJobsAnalysis);
      $stats = $createFilterDuplicatesJobsAnalysis->stats;
      $stats->batch_size(1);
      if($pair_aligner_conf->{'max_parallel_workers'}) {
          $stats->hive_capacity($pair_aligner_conf->{'max_parallel_workers'});
      }
      $stats->update();
      $self->{'createFilterDuplicatesJobsAnalysis'} = $createFilterDuplicatesJobsAnalysis;
      
      $self->{'ctrlflow_adaptor'}->create_rule($self->{'chunkAndGroupDnaAnalysis'}, $createFilterDuplicatesJobsAnalysis);
  }

  #
  # create refCreateFilterDuplicatesJobs job
  #
  $input_id = {
        'logic_name'        => $refFilterDuplicatesAnalysis->logic_name,
        'collection_name'   => $pair_aligner_conf->{'target_collection_name'},
  };
  if ($target_dnaCollectionConf->{'region'}) {
      $input_id->{'region'} = $target_dnaCollectionConf->{'region'};
  }
  
  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
      -input_id       => $input_id,
      -analysis       => $self->{'createFilterDuplicatesJobsAnalysis'},
  );
}


sub storeMaskingOptions {
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

1;

