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

Bio::EnsEMBL::Compara::Production::DnaCollection

=head1 DESCRIPTION

DnaCollection is an object to hold a set of DnaFragChunkSet objects. 
Used in production to encapsulate particular genome/region/chunk/group DNA set
from the others.  To allow system to blast against self, and isolate different 
chunk/group sets of the same genome from each other.

=cut

package Bio::EnsEMBL::Compara::Production::DnaCollection;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument;

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods


sub new {
  my ($class, @args) = @_;

  my $self = $class->SUPER::new(@args);       # deal with Storable stuff

  $self->{'_object_list'} = [];

  if (scalar @args) {
    #do this explicitly.
    my ($description, $masking) = rearrange([qw(DESCRIPTION MASKING)], @args);

    $self->description($description)         if($description);
    $self->masking($masking)                 if($masking);
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


=head2 masking

  Arg [1]    : string $masking(optional)
  Example    :
  Description:
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub masking {
  my $self = shift;
  $self->{'_masking'} = shift if(@_);
  return $self->{'_masking'};
}


=head2 get_all_DnaFragChunkSets

  Example    : @dna = @{$dnaCollection->get_all_DnaFragChunkSets};
  Description: returns array reference to all the DnaFragChunkSet objects in this set
  Returntype : reference to array of Bio::EnsEMBL::Compara::Production::DnaFragChunkSet objects
  Exceptions :
  Caller     :

=cut

sub get_all_DnaFragChunkSets {
  my $self = shift;

  if (!$self->{'_object_list'} || !@{$self->{'_object_list'}}) {
      $self->{'_object_list'} = $self->adaptor->db->get_DnaFragChunkSetAdaptor->fetch_all_by_DnaCollection($self);
  }

  return $self->{'_object_list'};
}


1;
