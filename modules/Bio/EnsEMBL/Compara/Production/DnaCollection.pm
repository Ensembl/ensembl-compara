#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::DnaCollection

=head1 SYNOPSIS

=head1 DESCRIPTION

DnaColelction is an object to hold a super-set of DnaFragChunk, and/or DnaFragChunkSet 
objects.  Used in production to encapsulate particular genome/region/chunk/group DNA set
from the others.  To allow system to blast against self, and isolate different 
chunk/group sets of the same genome from each other.

=head1 CONTACT

Jessica Severin <jessica@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::DnaCollection;

use strict;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;
use Time::HiRes qw(time gettimeofday tv_interval);

sub new {
  my ($class, @args) = @_;

  my $self = {};
  bless $self,$class;

  $self->{'_object_list'} = [];
  $self->{'_dnafrag_id_list'} = [];
  $self->{'_dnafrag_id_hash'} = {};

  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $description, $adaptor) = rearrange([qw(DBID DESCRIPTION ADAPTOR)], @args);

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


sub add_dna_object {
  my ($self, $object) = @_;
  
  return unless(defined($object));
  unless($object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunk') or
         $object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunkSet'))
  {
    $self->throw(
      "arg must be a [Bio::EnsEMBL::Compara::Production::DnaFragChunk] ".
      "or [Bio::EnsEMBL::Compara::Production::DnaFragChunk] not a [$object]");
  }
  if ($object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunk')) {
    unless ($self->{'_dnafrag_id_hash'}->{$object->dnafrag_id}) {
      push @{$self->{'_dnafrag_id_list'}}, $object->dnafrag_id;
      $self->{'_dnafrag_id_hash'}->{$object->dnafrag_id} = 1;
    }
  }
  if ($object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunkSet')) {
    foreach my $dc (@{$object->get_all_DnaFragChunks}) {
      unless ($self->{'_dnafrag_id_hash'}->{$dc->dnafrag_id}) {
        push @{$self->{'_dnafrag_id_list'}}, $dc->dnafrag_id;
        $self->{'_dnafrag_id_hash'}->{$dc->dnafrag_id} = 1;
      }
    }
  }

  push @{$self->{'_object_list'}}, $object;
}

=head2 get_all_dna_objects

  Example    : @dna = @{$dnaCOllection->get_all_dna_objects};
  Description: returns array reference to all the DnaFragChunkand DnaFragChunkSet objects in this set
  Returntype : reference to array of Bio::EnsEMBL::Compara::Production::DnaFragChunk(DnaFragChunkSet) objects
  Exceptions :
  Caller     :

=cut

sub get_all_dna_objects {
  my $self = shift;
  return $self->{'_object_list'};
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
  return scalar(@{$self->{'_object_list'}});
}

=head2 get_all_dnafrag_ids

  Example    : @dnafrag_ids = @{$dnaCOllection->get_all_dnafrag_ids};
  Description: returns array reference to all the dnafrag_ids in this set
  Returntype : reference to array of integers
  Exceptions :
  Caller     :

=cut

sub get_all_dnafrag_ids {
  my $self = shift;
  return $self->{'_dnafrag_id_list'};
}

1;
