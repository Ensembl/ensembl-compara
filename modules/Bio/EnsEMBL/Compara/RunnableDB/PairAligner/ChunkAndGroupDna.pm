=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna

=head1 DESCRIPTION

This object chunks the DNA from a genome_db and creates and stores the chunks as
DnaFragChunk objects, which are grouped into DnaFragChunkSets in the compara database.
A DnaFragChunkSet contains one or more DnaFragChunk objects. A DnaFragChunkSet
is a member of a DnaCollection.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna;

use strict;
use warnings;

use Time::HiRes qw(time);

use Bio::EnsEMBL::Utils::Exception qw( throw );

use Bio::EnsEMBL::Compara::Locus;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::Production::DnaCollection;
use Bio::EnsEMBL::Compara::Utils::Preloader;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'region'            => undef,
        'group_set_size'    => 0,
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
  
  return 1;
}


sub run {
  my $self = shift;

  # main routine which takes a genome_db_id (from input_id) and
  # access the ensembl_core database, using the SliceAdaptor
  # it will load all slices, all genes, and all transcripts
  # and convert them into members to be stored into compara
  $self->create_chunks;
  
  return 1;
}


######################################
#
# subroutines
#
#####################################

sub create_chunks {
  my $self      = shift;

  my $genome_db = $self->param('genome_db');
  my $collectionDBA = $self->compara_dba->get_DnaCollectionAdaptor;
  my $masking = $self->param('masking');

  if ($self->param('collection_id')) {
    $self->param('dna_collection') = $collectionDBA->fetch_by_dbID($self->param('collection_id'));
  } elsif ($self->param('collection_name')) {

    $self->param('dna_collection', new Bio::EnsEMBL::Compara::Production::DnaCollection);
    $self->param('dna_collection')->description($self->param('collection_name'));
    $self->param('dna_collection')->masking($masking) if(defined($masking));
    $self->param('dna_collection')->adaptor($collectionDBA);

    $collectionDBA->store($self->param('dna_collection'));
    $self->param('collection_id', $self->param('dna_collection')->dbID);

  } else {
      throw("Must define either a collection_id or a collection_name");
  }
  throw("couldn't get a DnaCollection for ChunkAndGroup analysis\n") unless($self->param('dna_collection'));

    my $dnafrag_dba = $self->compara_dba->get_DnaFragAdaptor;
    my @regions_to_align;
    if (defined $self->param('region')) {
        # Support list of regions as a string in CSV format as follows:
        #     chromosome:1,scaffold:KN149822.1:25:1560,chromosome:2::154200
        my @region_list = split(/,/, $self->param('region'));
        my %regions;
        foreach my $region ( @region_list ) {
            my ($coord_system_name, $region_name, $region_start, $region_end) = split(/:/, $region);
            my $region_dnafrag = $dnafrag_dba->fetch_by_GenomeDB_and_name($genome_db, $region_name);
            die "Unknown dnafrag region '$region_name'\n" unless $region_dnafrag;
            my $locus = bless {
                'dnafrag'         => $region_dnafrag,
                'dnafrag_start'   => $region_start || 1,
                'dnafrag_end'     => $region_end || $region_dnafrag->length,
                'dnafrag_strand'  => 1,
            }, 'Bio::EnsEMBL::Compara::Locus';
            push @regions_to_align, $locus;
        }
    } else {
        my $dnafrag_list = $dnafrag_dba->fetch_all_by_GenomeDB(
            $genome_db,
            -IS_REFERENCE       => $self->param('include_non_reference') ? undef : 1,
            -CELLULAR_COMPONENT => $self->param('only_cellular_component'),
        );

        Bio::EnsEMBL::Compara::Utils::Preloader::load_all_AltRegions($self->compara_dba->get_DnaFragAltRegionAdaptor, $dnafrag_list);

        foreach my $dnafrag (@$dnafrag_list) {
            next if $dnafrag->coord_system_name eq 'lrg';
            push @regions_to_align, $dnafrag->get_alt_region || $dnafrag->as_locus;
        }
    }

    my $starttime = time();
    $self->param('chunkset_counter', 1);
    $self->define_new_chunkset;
    $self->create_dnafrag_chunks($_, $masking) for @regions_to_align;
    printf "genome_db_id %s : total time %d secs\n", $genome_db->dbID, time() - $starttime;
}

sub create_dnafrag_chunks {
  my $self = shift;
  my $locus = shift;
  my $masking = shift;

  my $region_start = $locus->dnafrag_start;
  my $region_end = $locus->dnafrag_end;

  #If chunk_size is not set then set it to be the fragment length 
  #overlap must be 0 in this case.
  my $chunk_size = $self->param('chunk_size');
  my $overlap = $self->param('overlap');
  if (!defined $chunk_size) {
      $chunk_size = $region_end;
      $overlap = 0;
  }

  print "dnafrag : ", $locus->dnafrag->display_id, "\n" if ($self->debug);
  print "  sequence length : ",$locus->length,"\n" if ($self->debug);
  print "chunk_size $chunk_size\n" if ($self->debug);

  #initialise chunk_start and chunk_end to be the dnafrag start and end
  my $chunk_start = $region_start;
  my $chunk_end = $region_start;

  while ($chunk_end < $region_end) {

    my $chunk = new Bio::EnsEMBL::Compara::Production::DnaFragChunk();
    $chunk->dnafrag($locus->dnafrag);
    $chunk->dnafrag_start($chunk_start);

    $chunk_end = $chunk_start + $chunk_size - 1;

    #if current $chunk_end is too long, trim to be $region_end
    if ($chunk_end > $region_end) {
	$chunk_end = $region_end;
    }
    $chunk->dnafrag_end($chunk_end);
    
    #set chunk masking
    $chunk->masking($masking);

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
}


sub define_new_chunkset {
    my ($self) = @_;

    # If the current chunkset is still empty we don't need to create a new one
    return if $self->param('current_chunkset') and !$self->param('current_chunkset')->count;

    my $new_chunkset = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet(
        -NAME => sprintf('collection_id:%d group:%d', $self->param('collection_id'), $self->param('chunkset_counter')),
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
            $self->param('current_cellular_component', $chunk->dnafrag->cellular_component);
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
