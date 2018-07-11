=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::Production::DnaCollectionAdaptor

=head1 DESCRIPTION

Adpter to DnaCollection objects/tables
DnaCollection is an object to hold a super-set of DnaFragChunkSet bjects.  
Used in production to encapsulate particular genome/region/chunk/group DNA set
from the others.  To allow system to blast against self, and isolate different 
chunk/group sets of the same genome from each other.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::DBSQL::DnaCollectionAdaptor;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::Production::DnaCollection;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Hive::Utils 'stringify';

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use DBI qw(:sql_types);

use base qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);

#
# STORE METHODS
#
################

=head2 store

  Arg [1]    : Bio::EnsEMBL::Compara::Production::DnaCollection
  Example    :
  Description: stores the DnaCollection object
  Returntype : int dbID of DnaCollection
  Exceptions :
  Caller     :

=cut

sub store {
    my ($self, $collection) = @_;
    
    assert_ref($collection, 'Bio::EnsEMBL::Compara::Production::DnaCollection', 'collection');

    my $dbID;

    if (my $other_collection = $self->_synchronise($collection)) {
        $dbID = $other_collection->dbID;

    } else {
        $dbID = $self->generic_insert('dna_collection', {
                'description'       => $collection->description,
                'dump_loc'          => $collection->dump_loc,
                'masking'           => $collection->masking,
            }, 'dna_collection_id');
    }
    $self->attach($collection, $dbID);
}

#
# FETCH METHODS
#
################


=head2 fetch_by_set_description

  Arg [1]    : string $set_description
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_by_set_description {
  my ($self,$set_description) = @_;

  unless(defined $set_description) {
    $self->throw("fetch_by_set_description must have a description");
  }

  $self->bind_param_generic_fetch($set_description, SQL_VARCHAR);
  return $self->generic_fetch_one('dc.description = ?');
}

#
# INTERNAL METHODS
#
###################

sub object_class {
    return 'Bio::EnsEMBL::Compara::Production::DnaCollection';
}


sub _tables {
  my $self = shift;

  return (['dna_collection', 'dc']);
}

sub _columns {
  my $self = shift;

  return qw (dc.dna_collection_id
             dc.description
             dc.dump_loc
             dc.masking);
}

sub _unique_attributes {
    return qw(
        description
    );
}


sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::Production::DnaCollection', [
          'dbID',
          '_description',
          '_dump_loc',
          '_masking',
      ] );
}

1;





