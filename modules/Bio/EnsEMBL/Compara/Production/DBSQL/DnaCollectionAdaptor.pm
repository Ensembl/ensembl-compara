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
  Description: stores the set of DnaFragChunk objects
  Returntype : int dbID of DnaCollection
  Exceptions :
  Caller     :

=cut

sub store {
    my ($self, $collection) = @_;
    
    assert_ref($collection, 'Bio::EnsEMBL::Compara::Production::DnaCollection', 'collection');
    my $description = $collection->description;
    my $dump_loc = $collection->dump_loc;
    my $masking_options;

    if ($collection->masking_options) {
        if (ref($collection->masking_options)) {
            #from masking_option_file
            $masking_options = stringify($collection->masking_options);
        } else {
            $masking_options = $collection->masking_options;
        }
    }

    my $sql = "INSERT ignore INTO dna_collection (description, dump_loc, masking_options) VALUES (?, ?, ?)";
    my $sth = $self->prepare($sql);

    my $insertCount=0;
    $insertCount = $sth->execute($description, $dump_loc, $masking_options);
    
    if($insertCount>0) {
        $collection->dbID( $self->dbc->db_handle->last_insert_id(undef, undef, 'dna_collection', 'dna_collection_id') );
        $sth->finish;
    } else {
        #INSERT ignore has failed on UNIQUE description
        #Try getting dna_collection with SELECT
        $sth->finish;
        my $sth2 = $self->prepare("SELECT dna_collection_id FROM dna_collection WHERE description=?");
        $sth2->execute($description);
        my($id) = $sth2->fetchrow_array();
        warn("DnaCollectionAdaptor: insert failed, but description SELECT failed too") unless($id);
        $collection->dbID($id);
        $sth2->finish;
    }
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

sub _tables {
  my $self = shift;

  return (['dna_collection', 'dc']);
}

sub _columns {
  my $self = shift;

  return qw (dc.dna_collection_id
             dc.description
             dc.dump_loc
             dc.masking_options);
}


sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my %collections_hash = ();

  while( my $row_hashref = $sth->fetchrow_hashref()) {

    my $collection = $collections_hash{$row_hashref->{'dna_collection_id'}};
    
    unless($collection) {
      $collection = Bio::EnsEMBL::Compara::Production::DnaCollection->new_fast({
            'dbID'              => $row_hashref->{'dna_collection_id'},
            'adaptor'           => $self,
            '_description'      => $row_hashref->{'description'},
            '_dump_loc'         => $row_hashref->{'dump_loc'},
            '_masking_options'  => $row_hashref->{'masking_options'},
      });

      $collections_hash{$collection->dbID} = $collection;
    }

    if (defined($row_hashref->{'description'})) {
      $collection->description($row_hashref->{'description'});
    }
    if (defined($row_hashref->{'dump_loc'})) {
      $collection->dump_loc($row_hashref->{'dump_loc'});
    }
    if (defined($row_hashref->{'masking_options'})) {
      $collection->masking_options($row_hashref->{'masking_options'});
    }
  }
  $sth->finish;

  my @collections = values( %collections_hash );

  return \@collections;
}

1;





