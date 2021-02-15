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

Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkSetAdaptor

=cut

package Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkSetAdaptor;

use strict;
use warnings;

use DBI qw(:sql_types);

use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;

use base qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);


#
# STORE METHODS
#
################

=head2 store

  Arg [1]    : Bio::EnsEMBL::Compara::Production::DnaFragChunkSet
  Example    :
  Description: stores the set of DnaFragChunk objects
  Returntype : int dbID of DnaFragChunkSet
  Exceptions :
  Caller     :

=cut

sub store {
  my ($self,$chunkSet) = @_;

  assert_ref($chunkSet, 'Bio::EnsEMBL::Compara::Production::DnaFragChunkSet', 'chunkSet');

  my $dbID = $self->generic_insert('dnafrag_chunk_set', {
          'dna_collection_id'   => $chunkSet->dna_collection_id || $chunkSet->dna_collection->dbID,
          'description'         => $chunkSet->description || undef,
      }, 'dnafrag_chunk_set_id');
  $self->attach($chunkSet, $dbID);

  return $dbID;
}

#
# FETCH METHODS
#
################


=head2 fetch_all_by_DnaCollection

  Arg [1]    : Bio::EnsEMBL::Compara::Production::DnaCollection $dna_collection
  Example    : $feat = $adaptor->fetch_all_by_dna_collection(1234);
  Description: Returns all the DnaFragChunkSets for this DnaCollection
  Returntype : Bio::EnsEMBL::Compara::Production::DnaFragChunkSet
  Exceptions : thrown if $dna_collection is not defined
  Caller     : general

=cut

sub fetch_all_by_DnaCollection {
    my ($self, $dna_collection) = @_;
    
    assert_ref($dna_collection, 'Bio::EnsEMBL::Compara::Production::DnaCollection');
    my $dna_collection_id = $dna_collection->dbID;

    $self->bind_param_generic_fetch($dna_collection_id, SQL_INTEGER);
    my $constraint = 'sc.dna_collection_id = ?';
    
    return $self->generic_fetch($constraint);
}


#
# INTERNAL METHODS
#
###################


sub _tables {
  my $self = shift;

  return (['dnafrag_chunk_set', 'sc']);
}


sub _columns {
  my $self = shift;

  return qw (sc.dna_collection_id
             sc.description
             sc.dnafrag_chunk_set_id);
}


sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::Production::DnaFragChunkSet', [
          '_dna_collection_id',
          '_description',
          'dbID',
      ] );
}


1;
