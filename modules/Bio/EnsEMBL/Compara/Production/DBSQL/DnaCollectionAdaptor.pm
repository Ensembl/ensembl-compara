=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::Production::DnaCollectionAdaptor

=head1 SYNOPSIS

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
use Bio::EnsEMBL::Compara::Production::DnaCollection;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Hive::Utils 'stringify';

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

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
    
    unless($collection->isa('Bio::EnsEMBL::Compara::Production::DnaCollection')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::Production::DnaCollection] "
              . "not a $collection");
    }
    my $description = $collection->description if ($collection->description);
    my $dump_loc = $collection->dump_loc if ($collection->dump_loc);
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
        $collection->dbID( $sth->{'mysql_insertid'} );
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


=head2 fetch_by_dbID

  Arg [1]    : int $id
               the unique database identifier for the feature to be obtained
  Example    : $feat = $adaptor->fetch_by_dbID(1234);
  Description: Returns the feature created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::Compara::Production::DnaCollection
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_by_dbID{
  my ($self,$id) = @_;

  unless(defined $id) {
    throw("fetch_by_dbID must have an id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${syn}.${name}_id = $id";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}

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
    throw("fetch_by_set_description must have a description");
  }

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "dc.description = '$set_description'";
  #print("fetch_by_set_name contraint:\n$constraint\n");

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
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

sub _default_where_clause {
  my $self = shift;
  return '';
}

sub _final_clause {
  my $self = shift;

  return '';
}


=head2 _generic_fetch

  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
  Arg [2]    : (optional) string $logic_name
               the logic_name of the analysis of the features to obtain
  Example    : $fts = $a->_generic_fetch('contig_id in (1234, 1235)', 'Swall');
  Description: Performs a database fetch and returns feature objects in
               contig coordinates.
  Returntype : listref of Bio::EnsEMBL::SeqFeature in contig coordinates
  Exceptions : none
  Caller     : BaseFeatureAdaptor, ProxyDnaAlignFeatureAdaptor::_generic_fetch

=cut
  
sub _generic_fetch {
  my ($self, $constraint, $join) = @_;
  
  my @tables = $self->_tables;
  my $columns = join(', ', $self->_columns());
  
  if ($join) {
    foreach my $single_join (@{$join}) {
      my ($tablename, $condition, $extra_columns) = @{$single_join};
      if ($tablename && $condition) {
        push @tables, $tablename;
        
        if($constraint) {
          $constraint .= " AND $condition";
        } else {
          $constraint = " $condition";
        }
      } 
      if ($extra_columns) {
        $columns .= ", " . join(', ', @{$extra_columns});
      }
    }
  }
      
  #construct a nice table string like 'table1 t1, table2 t2'
  my $tablenames = join(', ', map({ join(' ', @$_) } @tables));
  my $sql = "SELECT $columns FROM $tablenames";

  my $default_where = $self->_default_where_clause;
  my $final_clause = $self->_final_clause;

  #append a where clause if it was defined
  if($constraint) { 
    $sql .= " WHERE $constraint ";
    if($default_where) {
      $sql .= " AND $default_where ";
    }
  } elsif($default_where) {
    $sql .= " WHERE $default_where ";
  }

  #append additional clauses which may have been defined
  $sql .= " $final_clause";

  my $sth = $self->prepare($sql);
  $sth->execute;

  #print STDERR $sql,"\n";

  return $self->_objs_from_sth($sth);
}


sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my $collections_hash = {};
  my $chunkDBA = $self->db->get_DnaFragChunkAdaptor;
  my $chunkSetDBA = $self->db->get_DnaFragChunkSetAdaptor;

  while ($sth->fetch()) {
    my $collection = $collections_hash->{$column{'dna_collection_id'}};
    
    unless($collection) {
      $collection = new Bio::EnsEMBL::Compara::Production::DnaCollection
                -dbid            => $column{'dna_collection_id'},
                -description     => $column{'description'},
                -dump_loc        => $column{'dump_loc'},
                -masking_options => $column{'masking_options'},
                -adaptor     => $self;
      $collections_hash->{$collection->dbID} = $collection;
    }

    if (defined($column{'description'})) {
      $collection->description($column{'description'});
    }
    if (defined($column{'dump_loc'})) {
      $collection->dump_loc($column{'dump_loc'});
    }
    if (defined($column{'masking_options'})) {
      $collection->masking_options($column{'masking_options'});
    }
  }
  $sth->finish;

  my @collections = values(%{$collections_hash});

  return \@collections;
}

1;





