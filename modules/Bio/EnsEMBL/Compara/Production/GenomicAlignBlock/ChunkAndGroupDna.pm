#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ChunkAndGroupDna

=cut

=head1 SYNOPSIS

my $db       = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ChunkAndGroupDna->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object chunks the Dna from a genome_db and creates and stores the
chunks as DnaFragChunk objects into the compara database

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ChunkAndGroupDna;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception qw( throw warning verbose );

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::Production::DnaCollection;

use Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor;

use Bio::EnsEMBL::Analysis::RunnableDB;
use Bio::EnsEMBL::Hive::Process;

our @ISA = qw(Bio::EnsEMBL::Hive::Process Bio::EnsEMBL::Analysis::RunnableDB);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #
  # parameters which can be set either via
  # $self->parameters OR
  # $self->input_id
  #
  $self->{'genome_db_id'}             = 0;  # 'gdb'

  #set default store_seq to 1 so that the sequence table is populated during
  #the chunking process rather than later during eg Blastz analysis.
  $self->{'store_seq'}                = 1;
  $self->{'store_chunk'}              = 0;
  $self->{'overlap'}                  = 0;
  $self->{'chunk_size'}               = undef;
  $self->{'region'}                   = undef;
  $self->{'masking_analysis_data_id'} = 0;
  $self->{'masking_options'}          = undef;
  $self->{'group_set_size'}           = undef;
  $self->{'include_non_reference'}    = 0;     # eg haplotypes
  $self->{'include_duplicates'}       = 0;     # eg PAR region


  $self->{'analysis_job'}             = undef;
  $self->{'create_analysis_prefix'}   = undef; # 'analysis', 'job'
  $self->{'collection_id'}            = undef;
  $self->{'collection_name'}          = undef;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  throw("No genome_db specified") unless defined($self->{'genome_db_id'});
  $self->print_params;
  
  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  #get the Compara::GenomeDB object for the genome_db_id
  $self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->
                           fetch_by_dbID($self->{'genome_db_id'});
  throw("Can't fetch genome_db for id=".$self->{'genome_db_id'}) unless($self->{'genome_db'});

    
  #using genome_db_id, connect to external core database
  my $coreDBA = $self->{'genome_db'}->db_adaptor();  
  throw("Can't connect to genome database for id=".$self->{'genome_db_id'}) unless($coreDBA);
  
  return 1;
}


sub run
{
  my $self = shift;

  # main routine which takes a genome_db_id (from input_id) and
  # access the ensembl_core database, useing the SliceAdaptor
  # it will load all slices, all genes, and all transscripts
  # and convert them into members to be stored into compara
  $self->create_chunks;
  
  return 1;
}


sub write_output 
{  
  my $self = shift;

  my $outputHash = {};
  $outputHash = eval($self->input_id) if(defined($self->input_id));
  $outputHash->{'collection_id'} = $self->{'dna_collection'}->dbID;
  my $output_id = main::encode_hash($outputHash);

  print("output_id = $output_id\n");
  $self->input_id($output_id);                    
  return 1;
}



######################################
#
# subroutines
#
#####################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");
  
  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }
  
  if($params->{'input_data_id'}) {
    my $input_id = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($params->{'input_data_id'});
    $self->get_params($input_id);
  }
      
  $self->{'store_seq'} = $params->{'store_seq'} if(defined($params->{'store_seq'}));
  $self->{'store_chunk'} = $params->{'store_chunk'} if(defined($params->{'store_chunk'}));
  $self->{'chunk_size'} = $params->{'chunk_size'} if(defined($params->{'chunk_size'}));
  $self->{'overlap'} = $params->{'overlap'} if(defined($params->{'overlap'}));

  $self->{'dump_loc'} = $params->{'dump_loc'} if(defined($params->{'dump_loc'}));

  $self->{'genome_db_id'} = $params->{'gdb'} if(defined($params->{'gdb'}));
  $self->{'genome_db_id'} = $params->{'genome_db_id'} if(defined($params->{'genome_db_id'}));

  $self->{'region'} = $params->{'region'} if(defined($params->{'region'}));

  $self->{'masking_options'} = $params->{'masking_options'}
    if(defined($params->{'masking_options'}));
  $self->{'masking_analysis_data_id'} = $params->{'masking_analysis_data_id'}
    if(defined($params->{'masking_analysis_data_id'}));
    
  $self->{'create_analysis_prefix'} = $params->{'analysis_template'} 
    if(defined($params->{'analysis_template'}));
  $self->{'analysis_job'} = $params->{'analysis_job'} if(defined($params->{'analysis_job'}));

  $self->{'group_set_size'} = $params->{'group_set_size'} if(defined($params->{'group_set_size'}));

  $self->{'collection_name'} = $params->{'collection_name'} if(defined($params->{'collection_name'}));
  $self->{'collection_id'} = $params->{'collection_id'} if(defined($params->{'collection_id'}));

  $self->{'include_non_reference'} = $params->{'include_non_reference'} if(defined($params->{'include_non_reference'}));
  $self->{'include_duplicates'} = $params->{'include_duplicates'} if(defined($params->{'include_duplicates'}));
  
  return;

}


sub print_params {
  my $self = shift;

  print(" params:\n");
  print("   genome_db_id             : ", $self->{'genome_db_id'},"\n");
  print("   region                   : ", $self->{'region'},"\n") if($self->{'region'});
  print("   store_seq                : ", $self->{'store_seq'},"\n");
  print("   store_chunk              : ", $self->{'store_chunk'},"\n");
  print("   chunk_size               : ", $self->{'chunk_size'},"\n");
  print("   overlap                  : ", $self->{'overlap'} ,"\n");
  print("   masking_analysis_data_id : ", $self->{'masking_analysis_data_id'} ,"\n");
  print("   masking_options          : ", $self->{'masking_options'} ,"\n") if($self->{'masking_options'});
  print("   include_non_reference    : ", $self->{'include_non_reference'} ,"\n");
  print("   include_duplicates       : ", $self->{'include_duplicates'} ,"\n");

}


sub create_chunks
{
  my $self      = shift;

  my $genome_db = $self->{'genome_db'};

  my $collectionDBA = $self->{'comparaDBA'}->get_DnaCollectionAdaptor;
  if ($self->{'collection_id'}) {
    $self->{'dna_collection'} = $collectionDBA->fetch_by_dbID($self->{'collection_id'});
  } else {
    $self->{'dna_collection'} = new Bio::EnsEMBL::Compara::Production::DnaCollection;
    $self->{'dna_collection'}->description($self->{'collection_name'});
    $self->{'dna_collection'}->dump_loc($self->{'dump_loc'}) if(defined($self->{'dump_loc'}));
    $collectionDBA->store($self->{'dna_collection'});
  }
  throw("couldn't get a DnaCollection for ChunkAndGroup analysis\n") unless($self->{'dna_collection'});
  
  $genome_db->db_adaptor->dbc->disconnect_when_inactive(0);
  my $SliceAdaptor = $genome_db->db_adaptor->get_SliceAdaptor;
  my $dnafragDBA = $self->{'comparaDBA'}->get_DnaFragAdaptor;

  my $chromosomes = [];
  if(defined $self->{'region'}) {
    my ($coord_system_name, $seq_region_name, $seq_region_start, $seq_region_end) = split(/:/,  $self->{'region'});
    if (defined $seq_region_name && $seq_region_name ne "") {
      print("fetch by region coord:$coord_system_name seq_name:$seq_region_name\n");
      push @{$chromosomes}, $SliceAdaptor->fetch_by_region($coord_system_name, $seq_region_name);
    } else {
      print("fetch by region coord:$coord_system_name\n");
      $chromosomes = $SliceAdaptor->fetch_all($coord_system_name);
    }
  } else {
      #default for $include_non_reference = 0, $include_duplicates = 0
    $chromosomes = $SliceAdaptor->fetch_all('toplevel',undef, $self->{'include_non_reference'}, $self->{'include_duplicates'});
  }
  print("number of seq_regions ".scalar @{$chromosomes}."\n");

  $self->{'chunkset_counter'} = 1;
  $self->{'current_chunkset'} = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
  $self->{'current_chunkset'}->description(sprintf("collection_id:%d group:%d",
                                 $self->{'dna_collection'}->dbID, 
                                 $self->{'chunkset_counter'}++));

  #Temporary fix to problem in core when masking haplotypes because the
  #assembly mapper is cached but shouldn't be
  #if including haplotypes
  my $asm;
  if ($self->{'include_non_reference'}) {
      my $asma = $genome_db->db_adaptor->get_AssemblyMapperAdaptor;
      my $csa = $genome_db->db_adaptor->get_CoordSystemAdaptor;
      my $cs1 = $csa->fetch_by_name("Chromosome",$genome_db->assembly);
      my $cs2 = $csa->fetch_by_name("Contig");
      $asm = $asma->fetch_by_CoordSystems($cs1,$cs2);
  }

  my $starttime = time();
  foreach my $chr (@{$chromosomes}) {
    #print "fetching dnafrag\n";
    if (defined $self->{'region'}) {
      next unless (scalar @{$chr->get_all_Attributes('toplevel')});
    }

    my ($dnafrag) = @{$dnafragDBA->fetch_all_by_GenomeDB_region(
                      $genome_db,
                      $chr->coord_system->name(), #$self->{'coordinate_system'},
                      $chr->seq_region_name)};

    #if($dnafrag) { print("  already stores as dbID ", $dnafrag->dbID, "\n"); }
    unless($dnafrag) {
      #
      # create dnafrag for this chromosome
      #
      #print "loading dnafrag for ".$chr->name."...\n";
      $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
      $dnafrag->name($chr->seq_region_name); #ie just 22
      $dnafrag->genome_db($genome_db);
      $dnafrag->coord_system_name($chr->coord_system->name());
      $dnafrag->length($chr->length);
      $dnafragDBA->store_if_needed($dnafrag);
    }
    $self->create_dnafrag_chunks($dnafrag, $chr->start, $chr->end);
    #Temporary fix to problem in core when masking haplotypes because the
    #assembly mapper is cached but shouldn't be  
    if (defined $asm) {
	$asm->flush;
    }
  }

  #save the current_chunkset if it isn't empty
  if($self->{'current_chunkset'}->count > 0) {
    $self->{'comparaDBA'}->get_DnaFragChunkSetAdaptor->store($self->{'current_chunkset'});
    #$self->submit_job($self->{'current_chunkset'});
    $self->{'dna_collection'}->add_dna_object($self->{'current_chunkset'});
  }

  #
  # finish by storing all the dna_objects of the collection 
  #
  $collectionDBA->store($self->{'dna_collection'});

  print "genome_db ",$genome_db->dbID, " : total time ", (time()-$starttime), " secs\n";

}


sub create_dnafrag_chunks {
  my $self = shift;
  my $dnafrag = shift;
  my $region_start = (shift or 1);
  my $region_end = (shift or $dnafrag->length);

 #return if($dnafrag->display_id =~ /random/);

  my $dnafragDBA = $self->{'comparaDBA'}->get_DnaFragAdaptor;

  my ($coord_system_name, $seq_region_name, $seq_region_start, $seq_region_end) = split(/:/,  $self->{'region'})
    if($self->{'region'});

  if (defined $seq_region_start && defined $seq_region_end) {
    $region_end = $seq_region_end;
    $region_start = $seq_region_start;
  }

  #If chunk_size is not set then set it to be the fragment length 
  #overlap must be 0 in this case.
  my $chunk_size = $self->{'chunk_size'};
  my $overlap = $self->{'overlap'};
  if (!defined $chunk_size) {
      $chunk_size = $region_end;
      $overlap = 0;
  }

  #print "dnafrag : ", $dnafrag->display_id, "n";
  #print "  sequence length : ",$length,"\n";

  my $lasttime = time();

  #initialise chunk_start and chunk_end to be the dnafrag start and end
  my $chunk_start = $region_start;
  my $chunk_end = $region_start;

  while ($chunk_end < $region_end) {

    my $chunk = new Bio::EnsEMBL::Compara::Production::DnaFragChunk();
    $chunk->dnafrag($dnafrag);
    $chunk->seq_start($chunk_start);
    
    $chunk_end = $chunk_start + $chunk_size - 1;

    #if current $chunk_end is too long, trim to be $region_end
    if ($chunk_end > $region_end) {
	$chunk_end = $region_end;
    }
    $chunk->seq_end($chunk_end);

    $chunk->masking_analysis_data_id($self->{'masking_analysis_data_id'});
    if($self->{'masking_options'}) {
      $chunk->masking_options($self->{'masking_options'});
    }

    #Store the sequence at this point, rather than in the blastz analysis
    if($self->{'store_seq'}) {

	#Set the masking_options variable for the masking_analysis_data_id
	if (!$self->{'_masking_options'} && $chunk->masking_analysis_data_id) {
	    $chunk->masking_options($self->{'comparaDBA'}->get_DnaFragChunkAdaptor->_fetch_MaskingOptions_by_dbID($chunk->masking_analysis_data_id));
	}

      $chunk->bioseq; #fetches sequence and stores internally in ->sequence variable
    }

    #print "store chunk " . $chunk->dnafrag->name . " " . $chunk->seq_start . " " . $chunk->seq_end . " " . length($chunk->bioseq->seq) . "\n";

    $self->{'comparaDBA'}->get_DnaFragChunkAdaptor->store($chunk);

    # do grouping if requested
    if($self->{'group_set_size'} and ($chunk->length < $self->{'group_set_size'})) {
      if(($self->{'current_chunkset'}->count > 0) and 
         (($self->{'current_chunkset'}->total_basepairs + $chunk->length) > $self->{'group_set_size'})) 
      {
        #set has hit max, so save it
        $self->{'comparaDBA'}->get_DnaFragChunkSetAdaptor->store($self->{'current_chunkset'});
        $self->{'dna_collection'}->add_dna_object($self->{'current_chunkset'});
        #$self->submit_job($self->{'current_chunkset'});
        if($self->debug) {
          printf("created chunkSet(%d) %d chunks, %1.3f mbase\n",
                 $self->{'current_chunkset'}->dbID, $self->{'current_chunkset'}->count, 
                 $self->{'current_chunkset'}->total_basepairs/1000000.0);
        }
        $self->{'current_chunkset'} = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;        
        $self->{'current_chunkset'}->description(sprintf("collection_id:%d group:%d",
                                       $self->{'dna_collection'}->dbID, 
                                       $self->{'chunkset_counter'}++));
      }

      $self->{'current_chunkset'}->add_DnaFragChunk($chunk);
      if($self->debug) {
        printf("chunkSet %d chunks, %1.3f mbase\n",
               $self->{'current_chunkset'}->count, 
               $self->{'current_chunkset'}->total_basepairs/1000000.0);
      }
  }
    else {
      #not doing grouping so put the $chunk directly into the collection
      $self->{'dna_collection'}->add_dna_object($chunk);
      if($self->debug) {
        printf("dna_collection : chunk (%d) %s\n",$chunk->dbID, $chunk->display_id);
      }
    }
    
    $self->submit_job($chunk) if($self->{'analysis_job'});
    $self->create_chunk_analysis($chunk) if($self->{'create_analysis_prefix'});

    #This is very important, otherwise it leaks
    undef($chunk->{'_sequence'});

    #These 2 don't seem to have any effect
    #undef($chunk->{'_slice'});
    #undef($chunk);
    $chunk_start = $chunk_end - $overlap + 1;
  }

  #print "Done\n";
  #print scalar(time()-$lasttime), " secs to chunk, and store\n";
}

sub submit_job {
  my $self  = shift;
  my $chunk = shift;

  unless($self->{'submit_analysis'}) {
    #print("\ncreate Submit Analysis\n");
    my $gdb = $chunk->dnafrag->genome_db;
    my $logic_name = $self->{'analysis_job'} ."_". $gdb->dbID ."_". $gdb->assembly;

    #print("  see if analysis '$logic_name' is in database\n");
    my $analysis =  $self->{'comparaDBA'}->get_AnalysisAdaptor->fetch_by_logic_name($logic_name);
    #if($analysis) { print("  YES in database with analysis_id=".$analysis->dbID()); }

    unless($analysis) {
      #print("  NOPE: go ahead and insert\n");
      $analysis = Bio::EnsEMBL::Analysis->new(
          -db              => '',
          -db_file         => '',
          -db_version      => '1',
          -parameters      => "",
          -logic_name      => $logic_name,
          -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        );
      $self->db->get_AnalysisAdaptor()->store($analysis);

      my $stats = $analysis->stats;
      $stats->batch_size(3);
      $stats->hive_capacity(11);
      $stats->status('BLOCKED');
      $stats->update();
    }
    $self->{'submit_analysis'} = $analysis;
  }

  my $input_id = "{'qyChunk'=>" . $chunk->dbID . "}";
  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $self->{'submit_analysis'},
        -input_job_id   => 0,
        );

  return;        
}


sub create_chunk_analysis {
  #routine to create one analysis per chunk
  my $self  = shift;
  my $chunk = shift;

  my $analysisDBA = $self->db->get_AnalysisAdaptor();
  my $gdb = $chunk->dnafrag->genome_db;
  my $logic_name = $self->{'create_analysis_prefix'}
                  ."_". $gdb->dbID
                  ."_". $gdb->assembly
                  ."_". $chunk->dbID;

  #print("look for analysis ", $self->{'create_analysis_prefix'}, "\n");
  my $analysis = $analysisDBA->fetch_by_logic_name($self->{'create_analysis_prefix'});
  unless($analysis) {  
    $analysis = Bio::EnsEMBL::Analysis->new(
      -db              => '',
      -db_file         => '',
      -db_version      => '1',
      -logic_name      => $logic_name,
      -program         => 'blastz',
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::BlastZ',
    );
  }
  return unless($analysis);

  my $template_analysis_stats = $analysis->stats;
  
  $analysis->adaptor(0);
  $analysis->dbID(0);
  $analysis->logic_name($logic_name);
  #print("new logic_name : ", $analysis->logic_name, "\n");
  
  my $param_hash = {};                        
  if($analysis->parameters and ($analysis->parameters =~ /^{/)) {
    #print("parsing parameters : ", $analysis->parameters, "\n");
    $param_hash = eval($analysis->parameters);
  }
  $param_hash->{'dbChunk'} = $chunk->dbID;
  $analysis->parameters(main::encode_hash($param_hash));
  #print("new parameters : ", $analysis->parameters, "\n");
  $analysisDBA->store($analysis);

  my $stats = $analysis->stats;
  $stats->batch_size($template_analysis_stats->batch_size);
  $stats->hive_capacity($template_analysis_stats->hive_capacity);
  $stats->update();
  
  return;
}

1;
