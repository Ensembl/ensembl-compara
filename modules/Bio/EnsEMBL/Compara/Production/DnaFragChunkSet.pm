=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::Production::DnaFragChunkSet

=head1 SYNOPSIS

=head1 DESCRIPTION

An object to hold a set or group of DnaFragChunk objects.  Used in production to reduce
overhead of feeding sequences into alignment programs like (b)lastz and exonerate.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;

use strict;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;
use Time::HiRes qw(time gettimeofday tv_interval);

sub new {
  my ($class, @args) = @_;

  my $self = {};
  bless $self,$class;

  $self->{'_cached_chunk_list'} = undef;
  $self->{'_total_basepairs'} = 0;

  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $description, $adaptor, $dna_collection_id) = rearrange([qw(DBID NAME ADAPTOR DNA_COLLECTION_ID)], @args);

    $self->dbID($dbid)                           if($dbid);
    $self->description($description)             if($description);
    $self->adaptor($adaptor)                     if($adaptor);
    $self->dna_collection_id($dna_collection_id) if($dna_collection_id);
  }
  return $self;
}

=head2 adaptor

 Title   : adaptor
 Usage   :
 Function: getter/setter of the adaptor for this object
 Example :
 Returns :
 Args    :

=cut

sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}


=head2 dbID

  Arg [1]    : int $dbID (optional)
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub dbID {
  my $self = shift;
  $self->{'_dbID'} = shift if(@_);
  return $self->{'_dbID'};
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
      if (defined ($self->{'_adaptor'}) and defined($self->{'_dna_collection_id'})) {
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

  unless(defined($chunk) and
         $chunk->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunk'))
  {
    $self->throw(
      "chunk arg must be a [Bio::EnsEMBL::Compara::Production::DnaFragChunk] ".
      "not a [$chunk]");
  }

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

1;
