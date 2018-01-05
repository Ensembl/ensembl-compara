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

Bio::EnsEMBL::Compara::Production::DnaFragChunkSet

=head1 DESCRIPTION

An object to hold a set or group of DnaFragChunk objects.  Used in production to reduce
overhead of feeding sequences into alignment programs like (b)lastz and exonerate.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;

use strict;
use warnings;

use File::Path;
use File::Basename;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use Bio::EnsEMBL::Hive::Utils 'dir_revhash';

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods


sub new {
  my ($class, @args) = @_;

  my $self = $class->SUPER::new(@args);       # deal with Storable stuff

  $self->{'_cached_chunk_list'} = undef;
  $self->{'_total_basepairs'} = 0;

  if (scalar @args) {
    #do this explicitly.
    my ($description, $dna_collection_id) = rearrange([qw(NAME DNA_COLLECTION_ID)], @args);

    $self->description($description)             if($description);
    $self->dna_collection_id($dna_collection_id) if($dna_collection_id);
  }
  return $self;
}

=head2 description

  Arg [1]    : string $description (optional)
  Example    :
  Description:
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub description {
  my $self = shift;
  $self->{'_description'} = shift if(@_);
  return $self->{'_description'};
}

=head2 dna_collection

  Arg [1]    :  Bio::EnsEMBL::Compara::Production::DnaCollection $dna_collection (optional)
  Example    :
  Description:
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub dna_collection {
  my ($self, $dna_collection) = @_;

  if (defined $dna_collection) {
      $self->{'_dna_collection'} = $dna_collection;
  } elsif (!defined ($self->{'_dna_collection'})) {
      #Try to get from other sources...
      if (defined ($self->{'adaptor'}) and defined($self->{'_dna_collection_id'})) {
          $self->{'_dna_collection'} = $self->adaptor->db->get_DnaCollectionAdaptor->fetch_by_dbID($self->dna_collection_id);
      }
  }

  return $self->{'_dna_collection'};
}

=head2 dna_collection_id

  Arg [1]    : int $dna_collection_id (optional)
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub dna_collection_id {
  my $self = shift;
  $self->{'_dna_collection_id'} = shift if(@_);
  return $self->{'_dna_collection_id'};
}

=head2 add_DnaFragChunk

  Arg [1]    : Bio::EnsEMBL::Compara::Production::DnaFragChunk $chunk
  Example    : $dnafrag_chunk_set->add_DnaFragChunk($chunk)
  Description: Add a Bio::EnsEMBL::Compara::Production::DnaFragChunk object to the _cached_chunk_list parameter
  Returntype : 
  Exceptions : throw if $chunk is not defined or if $chunk is not a Bio::EnsEMBL::Compara::Production::DnaFragChunk
  Caller     :

=cut

sub add_DnaFragChunk {
  my ($self, $chunk) = @_;

  assert_ref($chunk, 'Bio::EnsEMBL::Compara::Production::DnaFragChunk', 'chunk');

  $self->{'_cached_chunk_list'} = []
    unless(defined($self->{'_cached_chunk_list'}));

  push @{$self->{'_cached_chunk_list'}}, $chunk;
  $self->{'_total_basepairs'}=0; #reset so will be recalculated
}

=head2 get_all_DnaFragChunks

  Example    : @chunks = @{$chunkSet->get_all_DnaFragChunks};
  Description: returns array reference to all the DnaFragChunk objects in this set
               will lazy load the set if it was not previously loaded
  Returntype : reference to array of Bio::EnsEMBL::Compara::Production::DnaFragChunk objects
  Exceptions :
  Caller     :

=cut

sub get_all_DnaFragChunks {
  my $self = shift;

  if(!defined($self->{'_cached_chunk_list'}) and defined($self->adaptor)) {
    #lazy load all the DnaFragChunk objects
    $self->{'_cached_chunk_list'} = $self->adaptor->db->get_DnaFragChunkAdaptor->fetch_all_by_DnaFragChunkSet($self);

    $self->{'_total_basepairs'}=0; #reset so it's recalculated in
  }

  return $self->{'_cached_chunk_list'};
}

=head2 count

  Example    : $count = $chunkSet->count;
  Description: returns count of DnaFragChunks in this set
  Returntype : int
  Exceptions :
  Caller     :

=cut

sub count {
  my $self = shift;

  if (!$self->{'_cached_chunk_list'}) {
      return 0;
  }

  return scalar(@{$self->{'_cached_chunk_list'}});
}


=head2 total_basepairs

  Example    : $size = $chunkSet->total_basepairs;
  Description: returns summed length of all DnaFragChunks in this set
  Returntype : int
  Exceptions :
  Caller     :

=cut

sub total_basepairs {
  my $self = shift;

  unless($self->{'_total_basepairs'}) {
    $self->{'_total_basepairs'} =0;
    if($self->get_all_DnaFragChunks) {
      foreach my $chunk (@{$self->get_all_DnaFragChunks}) {
        $self->{'_total_basepairs'} += $chunk->length;
      }
    }
  }
  return $self->{'_total_basepairs'};
}


=head2 load_all_sequences

  Example     : $chunkset->load_all_sequences();
  Description : Loads all the chunk sequences with 1 API call
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub load_all_sequences {
    my $self = shift;

    if ($self->count == 1) {

        my $chunk = $self->get_all_DnaFragChunks()->[0];
        unless($chunk->sequence) {
            $chunk->masking_options($self->dna_collection->masking_options);
            # Will fetch the masked sequence from the core db and cache it in the object
            $chunk->fetch_masked_sequence();
        }

    } else {

        my $sequences = $self->adaptor->db->get_SequenceAdaptor->fetch_all_by_chunk_set_id($self->dbID);

        foreach my $chunk (@{$self->get_all_DnaFragChunks}) {

            if (my $this_seq_id = $chunk->sequence_id) {
                $chunk->sequence($sequences->{$this_seq_id}); #this sets $chunk->sequence_id=0
                $chunk->sequence_id($this_seq_id); #reset seq_id
            } else {
                $chunk->masking_options($self->dna_collection->masking_options);
                # Will fetch the masked sequence from the core db and cache it in the object
                $chunk->fetch_masked_sequence();
            }
        }
    }
}


=head2 dump_to_fasta_file

  Example     : $chunkset->dump_to_fasta_file();
  Description : Use BioPerl to print all the sequences in a Fasta file
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub dump_to_fasta_file {
    my ($self, $fastafile) = @_;

    mkpath(dirname($fastafile));

    open(my $fh, '>', $fastafile)
        or $self->throw("Error opening $fastafile for write");
    my $output_seq = Bio::SeqIO->new( -fh => $fh, -format => 'Fasta');

    foreach my $chunk (@{$self->get_all_DnaFragChunks}) {
        $output_seq->write_seq($chunk->bioseq);
    }

    close $fh;
}


=head2 dump_loc_file

  Example     : $chunk_set->dump_loc_file();
  Description : Returns the path to this ChunkSet in the dump location of its DnaCollection
  Returntype  : String
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub dump_loc_file {
    my $self = shift;
    my $dump_loc = $self->dna_collection->dump_loc;
    my $sub_dir  = dir_revhash($self->dbID);
    return sprintf('%s/%s/chunk_set_%s.fa', $dump_loc, $sub_dir, $self->dbID);
}




1;
