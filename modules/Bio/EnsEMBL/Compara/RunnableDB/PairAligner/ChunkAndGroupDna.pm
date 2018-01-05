=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna

=cut

=head1 DESCRIPTION

This object chunks the Dna from a genome_db and creates and stores the
chunks as DnaFragChunk objects are grouped into DnaFragChunkSets in the compara database.
A DnaFragChunkSet contains one or more DnaFragChunk objects. A DnaFragChunkSet is a member of a DnaCollection.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna;

use strict;
use warnings;

use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Utils::Exception qw( throw );
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::Production::DnaCollection;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'region'            => undef,
        'group_set_size'    => 0,
        'flow_chunksets'    => 1,
    }
}

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  throw("No genome_db specified") unless defined($self->param('genome_db_id'));
  
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

  #Create a StoreSequence job for each DnaFragChunkSet object 
  #to parallelise the storing of sequences in the Sequence table.
  if ($self->param('flow_chunksets')) {
      my $dna_objects = $self->param('dna_collection')->get_all_DnaFragChunkSets;
      die "No chunks were found" if ( scalar @$dna_objects < 1 );
      foreach my $dna_object (@$dna_objects) {
          my $hash_output = { 'chunkSetID' => $dna_object->dbID };
	    # Use branch2 to send data to StoreSequence:
            $self->dataflow_output_id($hash_output, 2 );
      }
  }
}



######################################
#
# subroutines
#
#####################################

sub create_chunks
{
  my $self      = shift;

  my $genome_db = $self->param('genome_db');
  my $collectionDBA = $self->compara_dba->get_DnaCollectionAdaptor;
  my $masking_options;

  #Get masking_options
  #Check only have either masking_options_file OR masking_options set
  if ($self->param('masking_options_file') && $self->param('masking_options')) {
      throw("ERROR: Only 'masking_options_file' or 'masking_options' maybe defined, not both");
  }
  
  #set masking_options parameter
  if ($self->param('masking_options_file')) {
      if (! -e $self->param('masking_options_file')) {
          throw("ERROR: masking_options_file " . $self->param('masking_options_file') . " does not exist\n");
      }
      $masking_options = do($self->param('masking_options_file'));
  } elsif ($self->param('masking_options')) {
      $masking_options = $self->param('masking_options');
  }

  if ($self->param('collection_id')) {
    $self->param('dna_collection') = $collectionDBA->fetch_by_dbID($self->param('collection_id'));
  } elsif ($self->param('collection_name')) {

    $self->param('dna_collection', new Bio::EnsEMBL::Compara::Production::DnaCollection);
    $self->param('dna_collection')->description($self->param('collection_name'));
    $self->param('dna_collection')->dump_loc($self->param('dump_loc')) if(defined($self->param('dump_loc')));
    $self->param('dna_collection')->masking_options($masking_options) if(defined($masking_options));
    $self->param('dna_collection')->adaptor($collectionDBA);

    $collectionDBA->store($self->param('dna_collection'));
    $self->param('collection_id', $self->param('dna_collection')->dbID);

  } else {
      throw("Must define either a collection_id or a collection_name");
  }
  throw("couldn't get a DnaCollection for ChunkAndGroup analysis\n") unless($self->param('dna_collection'));
  

  my $SliceAdaptor = $genome_db->db_adaptor->get_SliceAdaptor;
  my $dnafragDBA = $self->compara_dba->get_DnaFragAdaptor;

  my $chromosomes = [];
  my $preloaded_dnafrags = {};

 $genome_db->db_adaptor->dbc->prevent_disconnect( sub {

  my %single_fetch_components = ('PT' => 1, 'MT' => 1);
  if ($self->param('only_cellular_component') and $single_fetch_components{$self->param('only_cellular_component')}){
      # Optimization: for these components, we expect there is a single seq_region
      my $this_slice = $SliceAdaptor->fetch_by_region('toplevel', $self->param('only_cellular_component'));
      push(@$chromosomes, $this_slice);

  } elsif(defined $self->param('region')) {
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
  } elsif ($genome_db->genome_component) {
      # We're asked to align a genome component: only take the seq_regions
      # of that component
      $chromosomes = $SliceAdaptor->fetch_all_by_genome_component($genome_db->genome_component);
  } else {
      #default for $include_non_reference = 0, $include_duplicates = 0
    $chromosomes = $SliceAdaptor->fetch_all('toplevel',undef, $self->param('include_non_reference'), $self->param('include_duplicates'));
    $preloaded_dnafrags = { map {$_->name => $_} @{ $dnafragDBA->fetch_all_by_GenomeDB_region($genome_db) } }
  }
 } );

  print("number of seq_regions ".scalar @{$chromosomes}."\n");

  $self->param('chunkset_counter', 1);
  $self->define_new_chunkset;

  #Temporary fix to problem in core when masking haplotypes because the
  #assembly mapper is cached but shouldn't be
  #if including haplotypes
#  my $asm;
#  if (defined $self->param('include_non_reference')) {
#      my $asma = $genome_db->db_adaptor->get_AssemblyMapperAdaptor;
#      my $csa = $genome_db->db_adaptor->get_CoordSystemAdaptor;
#      my $cs1 = $csa->fetch_by_name("Chromosome",$genome_db->assembly);
#      my $cs2 = $csa->fetch_by_name("Contig");
#      $asm = $asma->fetch_by_CoordSystems($cs1,$cs2);
#  }
  my $starttime = time();

  foreach my $chr (@{$chromosomes}) {
    #print "fetching dnafrag\n";
    if (defined $self->param('region')) {
      unless(scalar @{$chr->get_all_Attributes('toplevel')}) {
        warn "No toplevel attributes, skipping this region";
      }
    }

    my $dnafrag = ($preloaded_dnafrags->{$chr->seq_region_name} || $dnafragDBA->fetch_by_GenomeDB_and_name($genome_db, $chr->seq_region_name));

    next if $self->param('only_cellular_component') && ($dnafrag->cellular_component ne $self->param('only_cellular_component'));

    #Uncomment following line to prevent import of missing dnafrags
    #next unless ($dnafrag);

    #if($dnafrag) { print("  already stores as dbID ", $dnafrag->dbID, "\n"); }
    unless($dnafrag) {
      #
      # try fetching dnafrag for this chromosome
      #
      $dnafrag = $dnafragDBA->fetch_by_GenomeDB_and_name($genome_db, $chr);
    }
    unless($dnafrag) {
      #
      # create dnafrag for this chromosome
      #
      #print "loading dnafrag for ".$chr->name."...\n";
      $dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new_from_Slice($chr, $genome_db);
      $dnafragDBA->store($dnafrag);
    }
    $dnafrag->{'_slice'} = $chr;
    $self->create_dnafrag_chunks($dnafrag, $masking_options, $chr->start, $chr->end);
    #Temporary fix to problem in core when masking haplotypes because the
    #assembly mapper is cached but shouldn't be  
    #if (defined $asm) {
#	$asm->flush;
#    }
  }

  print "genome_db ",$genome_db->dbID, " : total time ", (time()-$starttime), " secs\n";

}


sub create_dnafrag_chunks {
  my $self = shift;
  my $dnafrag = shift;
  my $masking_options = shift;
  my $region_start = (shift or 1);
  my $region_end = (shift or $dnafrag->length);

 #return if($dnafrag->display_id =~ /random/);

  #If chunk_size is not set then set it to be the fragment length 
  #overlap must be 0 in this case.
  my $chunk_size = $self->param('chunk_size');
  my $overlap = $self->param('overlap');
  if (!defined $chunk_size) {
      $chunk_size = $region_end;
      $overlap = 0;
  }

  #print "dnafrag : ", $dnafrag->display_id, "n";
  #print "  sequence length : ",$dnafrag->length,"\n";
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
    
    #set chunk masking_options
    $chunk->masking_options;

    # do grouping if requested
    if($self->param('group_set_size') and ($chunk->length < $self->param('group_set_size'))) {

      if(($self->param('current_chunkset')->count > 0) and 
         (($self->param('current_chunkset')->total_basepairs + $chunk->length) > $self->param('group_set_size'))) 
      {
          # This chunkset is full. Create a new one
          $self->define_new_chunkset;
      } 

      #store dnafrag_chunk_set if necessary to get hold of the dnafrag_chunk_set_id
        $self->store_chunk_in_chunkset($chunk);

      if($self->debug) {
        printf("chunkSet %d chunks, %1.3f mbase\n",
               $self->param('current_chunkset')->count, 
               $self->param('current_chunkset')->total_basepairs/1000000.0);
      }
    } else {
      #not doing grouping so put the $chunk directly into the collection

        #Create new current_chunkset object
        $self->define_new_chunkset;

        $self->store_chunk_in_chunkset($chunk);

      if($self->debug) {
        printf("dna_collection : chunk (%d) %s\n",$chunk->dbID, $chunk->display_id);
      }
  }
    

    #This is very important, otherwise it leaks
    undef($chunk->{'_sequence'});

    $chunk_start = $chunk_end - $overlap + 1;
 }

  #print "Done\n";
  #print scalar(time()-$lasttime), " secs to chunk, and store\n";
}

sub define_new_chunkset {
    my ($self) = @_;

    # If the current chunkset is still empty we don't need to create a new one
    return if $self->param('current_chunkset') and !$self->param('current_chunkset')->count;

    my $new_chunkset = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet(
        -NAME => sprintf('collection_id:%d group:%d', $self->param('dna_collection')->dbID, $self->param('chunkset_counter')),
        -DNA_COLLECTION_ID => $self->param('collection_id')
    );
    $self->param('current_chunkset', $new_chunkset);
    $self->param('chunkset_counter', $self->param('chunkset_counter')+1);
    $self->param('current_cellular_component', undef);
}

sub store_chunk_in_chunkset {
    my ($self, $chunk) = @_;

    # In some cases we don't want to mix different cellular components
    if ($self->param('current_cellular_component')) {
        if (!$self->param('mix_cellular_components') and ($self->param('current_cellular_component') ne $chunk->dnafrag->cellular_component)) {
            print "Creating new chunkset for ".$chunk->dnafrag->cellular_component."\n";
            $self->define_new_chunkset;
        }
    } else {
        $self->param('current_cellular_component', $chunk->dnafrag->cellular_component);
    }

    # Store the chunkset if it hasn't been stored before
    unless ($self->param('current_chunkset')->dbID) {
        $self->compara_dba->get_DnaFragChunkSetAdaptor->store($self->param('current_chunkset'));
    }
    # Add the chunk to the chunkset and store it
    $chunk->dnafrag_chunk_set_id($self->param('current_chunkset')->dbID);
    $self->param('current_chunkset')->add_DnaFragChunk($chunk);
    $self->compara_dba->get_DnaFragChunkAdaptor->store($chunk);
}

1;
