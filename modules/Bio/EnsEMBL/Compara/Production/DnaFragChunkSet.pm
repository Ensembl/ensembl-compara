#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::DnaFragChunkSet

=head1 SYNOPSIS

=head1 DESCRIPTION

An object to hold a set or group of DnaFragChunk objects.  Used in production to reduce
overhead of feeding sequences into alignment programs like blastz and exonerate.

=head1 CONTACT

Jessica Severin <jessica@ebi.ac.uk>

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

  $self->{'_dnafrag_chunk_id_list'} = [];
  $self->{'_cached_chunk_list'} = undef;
  $self->{'_total_basepairs'} = 0;

  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $description, $adaptor) = rearrange([qw(DBID NAME ADAPTOR)], @args);

    $self->dbID($dbid)               if($dbid);
    $self->description($description) if($description);
    $self->adaptor($adaptor)         if($adaptor);
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

=head2 dump_loc

  Arg [1]    : string $dump_loc (optional)
  Example    :
  Description:
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub dump_loc {
  my $self = shift;
  $self->{'_dump_loc'} = shift if(@_);
  return $self->{'_dump_loc'};
}

=head2 add_dnafrag_chunk_id

  Arg [1]    : $chunk_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub add_dnafrag_chunk_id {
  my $self = shift;
  my $count=0;

  if(@_) {
    my $chunk_id = shift;
    $count = push @{$self->{'_dnafrag_chunk_id_list'}}, $chunk_id;
    #print("added $count element to list\n");
    $self->{'_total_basepairs'}=0; #reset so will be recalculated
    if(defined($self->adaptor)) {
      $self->adaptor->store_link($self->dbID, $chunk_id);
    }
  }
  return $count
}

sub add_DnaFragChunk {
  my ($self, $chunk) = @_;

  unless(defined($chunk) and
         $chunk->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunk'))
  {
    $self->throw(
      "chunk arg must be a [Bio::EnsEMBL::Compara::Production::DnaFragChunk] ".
      "not a [$chunk]");
  }

  my $count = $self->add_dnafrag_chunk_id($chunk->dbID);

  $self->{'_cached_chunk_list'} = []
    unless(defined($self->{'_cached_chunk_list'}));
  
  push @{$self->{'_cached_chunk_list'}}, $chunk;

  return $count;
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
  if(!defined($self->{'_cached_chunk_list'}) and
     $self->count > 0 and defined($self->adaptor))
  {
    #lazy load all the DnaFragChunk objects
    $self->{'_cached_chunk_list'} =
      $self->adaptor->_fetch_all_DnaFragChunk_by_ids($self->dnafrag_chunk_ids);
    $self->{'_total_basepairs'}=0; #reset so it's recalculated
  }
  return $self->{'_cached_chunk_list'};
}

=head2 dnafrag_chunk_ids

  Example    : @chunk_ids = @{$chunkSet->dnafrag_chunk_ids};
  Description:
  Returntype : reference to array of dnafrag_chunk_id
  Exceptions :
  Caller     :

=cut

sub dnafrag_chunk_ids {
  my $self = shift;
  return $self->{'_dnafrag_chunk_id_list'};
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
  return scalar(@{$self->dnafrag_chunk_ids()});
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
