=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::Production::DnaCollection

=head1 SYNOPSIS

=head1 DESCRIPTION

DnaCollection is an object to hold a set of DnaFragChunkSet objects. 
Used in production to encapsulate particular genome/region/chunk/group DNA set
from the others.  To allow system to blast against self, and isolate different 
chunk/group sets of the same genome from each other.

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
    my ($dbid, $description, $adaptor, $dump_loc, $masking_options) = rearrange([qw(DBID DESCRIPTION ADAPTOR DUMP_LOC MASKING_OPTIONS)], @args);

    $self->dbID($dbid)                       if($dbid);
    $self->description($description)         if($description);
    $self->adaptor($adaptor)                 if($adaptor);
    $self->dump_loc($dump_loc)               if($dump_loc);
    $self->masking_options($masking_options) if($masking_options);
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

=head2 masking_options

  Arg [1]    : string $masking_options (optional)
  Example    :
  Description:
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub masking_options {
  my $self = shift;
  $self->{'_masking_options'} = shift if(@_);
  return $self->{'_masking_options'};
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

=head2 count

  Example    : $count = $chunkSet->count;
  Description: returns count of DnaFragChunkSets in this set
  Returntype : int
  Exceptions :
  Caller     :

=cut

sub count {
  my $self = shift;
  return scalar(@{$self->{'_object_list'}});
}

1;
