=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna

=cut

=head1 SYNOPSIS

my $db       = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna->new (
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

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception qw( throw warning verbose );

use Bio::EnsEMBL::DBLoader;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::Production::DnaCollection;

use Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor;

use Bio::EnsEMBL::Analysis::RunnableDB;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #set default store_seq to 0 so that the sequence table is NOT populated during
  #the chunking process. Have now added separate module StoreSequence to deal
  #with storing very fragmented genomes.
  $self->param('store_seq', 0);

  #whether to dataflow_output to store_sequence (true) or dump_large_nib_for_chains (false)
  unless (defined $self->param('flow_to_store_sequence')) {
      $self->param('flow_to_store_sequence', 1); 
  }

  throw("No genome_db specified") unless defined($self->param('genome_db_id'));
  $self->print_params;
  
  #get the Compara::GenomeDB object for the genome_db_id
  $self->param('genome_db', $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($self->param('genome_db_id')));
  throw("Can't fetch genome_db for id=".$self->param('genome_db_id')) unless($self->param('genome_db'));

  #using genome_db_id, connect to external core database
  my $coreDBA = $self->param('genome_db')->db_adaptor();  
  throw("Can't connect to genome database for id=".$self->param('genome_db_id')) unless($coreDBA);
  
  return 1;
}


sub run
{
  my $self = shift;

  # main routine which takes a genome_db_id (from input_id) and
  # access the ensembl_core database, using the SliceAdaptor
  # it will load all slices, all genes, and all transscripts
  # and convert them into members to be stored into compara
  $self->create_chunks;
  
  return 1;
}


sub write_output 
{  
  my $self = shift;

  #Create a StoreSequence job for each DnaFragChunk or DnaFragChunkSet object 
  #to parallelise the storing of sequences in the Sequence table.
  if ($self->param('flow_to_store_sequence')) {
      my $dna_objects = $self->param('dna_collection')->get_all_dna_objects;
      foreach my $dna_object (@$dna_objects) {
            my $object_id_name = $dna_object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunkSet')
                ? 'chunkSetID'
                : 'chunkID';

	    # Use branch2 to send data to StoreSequence:
            $self->dataflow_output_id( { $object_id_name => $dna_object->dbID }, 2 );
      }

      #Stop flow into dump_large_nib_for_chains on branch 1?
      $self->input_job->autoflow(0);
  }
  #Else flow on branch 1 to dump_large_nib_for_chains

  return 1;
}



######################################
#
# subroutines
#
#####################################

sub print_params {
  my $self = shift;

  print(" params:\n");
  print("   genome_db_id             : ", $self->param('genome_db_id'),"\n");
  print("   region                   : ", $self->param('region'),"\n") if($self->param('region'));
  print("   store_seq                : ", $self->param('store_seq'),"\n");
  print("   chunk_size               : ", $self->param('chunk_size'),"\n");
  print("   overlap                  : ", $self->param('overlap') ,"\n");
  print("   masking_analysis_data_id : ", $self->param('masking_analysis_data_id') ,"\n");
  print("   masking_options          : ", $self->param('masking_options') ,"\n") if($self->param('masking_options'));
  print("   include_non_reference    : ", $self->param('include_non_reference') ,"\n");
  print("   include_duplicates       : ", $self->param('include_duplicates') ,"\n");

}


sub create_chunks
{
  my $self      = shift;

  my $genome_db = $self->param('genome_db');

  my $collectionDBA = $self->compara_dba->get_DnaCollectionAdaptor;

  if ($self->param('collection_id')) {
    $self->param('dna_collection') = $collectionDBA->fetch_by_dbID($self->param('collection_id'));
  } elsif ($self->param('collection_name')) {
    $self->param('dna_collection', new Bio::EnsEMBL::Compara::Production::DnaCollection);
    $self->param('dna_collection')->description($self->param('collection_name'));
    $self->param('dna_collection')->dump_loc($self->param('dump_loc')) if(defined($self->param('dump_loc')));
    $collectionDBA->store($self->param('dna_collection'));
  } else {
      throw("Must define either a collection_id or a collection_name");
  }
  throw("couldn't get a DnaCollection for ChunkAndGroup analysis\n") unless($self->param('dna_collection'));
  
  $genome_db->db_adaptor->dbc->disconnect_when_inactive(0);
  my $SliceAdaptor = $genome_db->db_adaptor->get_SliceAdaptor;
  my $dnafragDBA = $self->compara_dba->get_DnaFragAdaptor;

  my $chromosomes = [];
  if(defined $self->param('region')) {
    #Support list of regions
    my @regions = split(/,/, $self->param('region'));  

    foreach my $region (@regions) {
        my ($coord_system_name, $seq_region_name, $seq_region_start, $seq_region_end) = split(/:/,  $region);
        if (defined $seq_region_name && $seq_region_name ne "") {
            print("fetch by region coord:$coord_system_name seq_name:$seq_region_name\n");
            my $slice;
            if (defined $seq_region_start && defined $seq_region_end) {
                $slice = $SliceAdaptor->fetch_by_region($coord_system_name, $seq_region_name, $seq_region_start, $seq_region_end);
                push @{$chromosomes}, $slice;
            } else {
                if (defined $self->param('include_non_reference')) {
                    $slice = $SliceAdaptor->fetch_by_region_unique($coord_system_name, $seq_region_name);
		    #If slice is not defined, try calling fetch_by_region instead
		    if (scalar @$slice == 0) {
			$slice = $SliceAdaptor->fetch_by_region($coord_system_name, $seq_region_name);
			push @{$chromosomes}, $slice;
		    } else {
			push @{$chromosomes}, @$slice;
		    }
                } else {
                    $slice = $SliceAdaptor->fetch_by_region($coord_system_name, $seq_region_name);
                    push @{$chromosomes}, $slice;
                }
            }
        } else {
            print("fetch by region coord:$coord_system_name\n");
            push @{$chromosomes}, $SliceAdaptor->fetch_all($coord_system_name);
        }
    }
  } else {
      #default for $include_non_reference = 0, $include_duplicates = 0
    $chromosomes = $SliceAdaptor->fetch_all('toplevel',undef, $self->param('include_non_reference'), $self->param('include_duplicates'));
  }

  print("number of seq_regions ".scalar @{$chromosomes}."\n");

  $self->param('chunkset_counter', 1);
  $self->param('current_chunkset', new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet);
  $self->param('current_chunkset')->description(sprintf("collection_id:%d group:%d",
                                 $self->param('dna_collection')->dbID, 
                                 $self->param('chunkset_counter')));

  $self->param('chunkset_counter', ($self->param('chunkset_counter') + 1));
  
  #Temporary fix to problem in core when masking haplotypes because the
  #assembly mapper is cached but shouldn't be
  #if including haplotypes
  my $asm;
  if (defined $self->param('include_non_reference')) {
      my $asma = $genome_db->db_adaptor->get_AssemblyMapperAdaptor;
      my $csa = $genome_db->db_adaptor->get_CoordSystemAdaptor;
      my $cs1 = $csa->fetch_by_name("Chromosome",$genome_db->assembly);
      my $cs2 = $csa->fetch_by_name("Contig");
      $asm = $asma->fetch_by_CoordSystems($cs1,$cs2);
  }
  my $starttime = time();
  foreach my $chr (@{$chromosomes}) {
    #print "fetching dnafrag\n";
    if (defined $self->param('region')) {
      unless(scalar @{$chr->get_all_Attributes('toplevel')}) {
        warn "No toplevel attributes, skipping this region";
      }
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

      #Need total length of dnafrag, not just end-start+1, otherwise the dnafrag_chunks are created
      #incorrectly because the chr->end becomes (end-start+1) but this could be less than chr->start
      #$dnafrag->length($chr->length);
      $dnafrag->length($chr->seq_region_length);
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
  if($self->param('current_chunkset')->count > 0) {
    $self->compara_dba->get_DnaFragChunkSetAdaptor->store($self->param('current_chunkset'));
    #$self->submit_job($self->{'current_chunkset'});
    $self->param('dna_collection')->add_dna_object($self->param('current_chunkset'));
  } else {
    warn "current_chunkset->count is zero => not adding it to the collection";
  }

  #
  # finish by storing all the dna_objects of the collection 
  #
  $collectionDBA->store($self->param('dna_collection'));

  print "genome_db ",$genome_db->dbID, " : total time ", (time()-$starttime), " secs\n";

}


sub create_dnafrag_chunks {
  my $self = shift;
  my $dnafrag = shift;
  my $region_start = (shift or 1);
  my $region_end = (shift or $dnafrag->length);

 #return if($dnafrag->display_id =~ /random/);

  my $dnafragDBA = $self->compara_dba->get_DnaFragAdaptor;

  #If chunk_size is not set then set it to be the fragment length 
  #overlap must be 0 in this case.
  my $chunk_size = $self->param('chunk_size');
  my $overlap = $self->param('overlap');
  if (!defined $chunk_size) {
      $chunk_size = $region_end;
      $overlap = 0;
  }

  #print "dnafrag : ", $dnafrag->display_id, "n";
  #print "  sequence length : ",$length,"\n";
  #print "chunk_size $chunk_size\n";

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

    $DB::single = 1;
    $chunk->masking_analysis_data_id($self->param('masking_analysis_data_id'));
    if($self->param('masking_options')) {
      $chunk->masking_options($self->param('masking_options'));
    }

    #Store the sequence at this point, rather than in the blastz analysis
    #only try to store the sequence if its length is less than that
    #allowed by myslwd max_allowed_packet=12M
    if($self->param('store_seq') && 
       ($chunk->seq_end - $chunk->seq_start + 1) <= 11500000) {

	#Set the masking_options variable for the masking_analysis_data_id
	if (!$self->param('_masking_options') && $chunk->masking_analysis_data_id) {
	    $chunk->masking_options($self->compara_dba->get_DnaFragChunkAdaptor->_fetch_MaskingOptions_by_dbID($chunk->masking_analysis_data_id));
	}

	$chunk->bioseq; #fetches sequence and stores internally in ->sequence variable
    }

    #print "store chunk " . $chunk->dnafrag->name . " " . $chunk->seq_start . " " . $chunk->seq_end . " " . length($chunk->bioseq->seq) . "\n";

    $self->compara_dba->get_DnaFragChunkAdaptor->store($chunk);

    # do grouping if requested but do not group MT chr
    if($self->param('group_set_size') and ($chunk->length < $self->param('group_set_size')) and $chunk->dnafrag->name ne "MT") {
      if(($self->param('current_chunkset')->count > 0) and 
         (($self->param('current_chunkset')->total_basepairs + $chunk->length) > $self->param('group_set_size'))) 
      {
        #set has hit max, so save it
        $self->compara_dba->get_DnaFragChunkSetAdaptor->store($self->param('current_chunkset'));
        $self->param('dna_collection')->add_dna_object($self->param('current_chunkset'));
        #$self->submit_job($self->{'current_chunkset'});
        if($self->debug) {
          printf("created chunkSet(%d) %d chunks, %1.3f mbase\n",
                 $self->param('current_chunkset')->dbID, $self->param('current_chunkset')->count, 
                 $self->param('current_chunkset')->total_basepairs/1000000.0);
        }
        $self->param('current_chunkset', new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet);        
        $self->param('current_chunkset')->description(sprintf("collection_id:%d group:%d",
                                       $self->param('dna_collection')->dbID, 
                                       $self->param('chunkset_counter')));
	$self->param('chunkset_counter',($self->param('chunkset_counter') + 1)); 
      }

      $self->param('current_chunkset')->add_DnaFragChunk($chunk);
      if($self->debug) {
        printf("chunkSet %d chunks, %1.3f mbase\n",
               $self->param('current_chunkset')->count, 
               $self->param('current_chunkset')->total_basepairs/1000000.0);
      }
  }
    else {
      #not doing grouping so put the $chunk directly into the collection
      $self->param('dna_collection')->add_dna_object($chunk);
      if($self->debug) {
        printf("dna_collection : chunk (%d) %s\n",$chunk->dbID, $chunk->display_id);
      }
    }
    
#    $self->submit_job($chunk) if($self->{'analysis_job'});
#    $self->create_chunk_analysis($chunk) if($self->{'create_analysis_prefix'});

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

1;
