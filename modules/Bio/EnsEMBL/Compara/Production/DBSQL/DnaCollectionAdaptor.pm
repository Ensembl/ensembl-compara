#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::DnaCollectionAdaptor

=head1 SYNOPSIS

=head1 DESCRIPTION

Adpter to DnaColelction objects/tables
DnaColelction is an object to hold a super-set of DnaFragChunk, and/or DnaFragChunkSet 
objects.  Used in production to encapsulate particular genome/region/chunk/group DNA set
from the others.  To allow system to blast against self, and isolate different 
chunk/group sets of the same genome from each other.

=head1 CONTACT

Jessica Severin <jessica@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::DBSQL::DnaCollectionAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Production::DnaCollection;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;

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

  my $sth;
  my $insertCount=0;
  
  #
  # first create/get the collection->dbID (from the subset table)
  #
  unless($collection->dbID and $collection->adaptor) {
    if(defined($collection->description) && defined($collection->dump_loc)) {
      $sth = $self->prepare("INSERT ignore INTO subset (description,dump_loc) VALUES (?,?)");
      $insertCount = $sth->execute($collection->description,$collection->dump_loc);
    } elsif(defined($collection->description)) {
      $sth = $self->prepare("INSERT ignore INTO subset (description) VALUES (?)");
      $insertCount = $sth->execute($collection->description);
    } else {
      $sth = $self->prepare("INSERT ignore INTO subset SET description=NULL");
      $insertCount = $sth->execute();
    }

    if($insertCount>0) {
      $collection->dbID( $sth->{'mysql_insertid'} );
    }
    else {
      #print("insert failed, do select\n");
      my $sth2 = $self->prepare("SELECT subset_id FROM subset WHERE description=?");
      $sth2->execute($collection->description);
      my($id) = $sth2->fetchrow_array();
      $collection->dbID($id);
      $sth2->finish;
    }
    $sth->finish;
  }
  throw("unable to create/get collection_id\n") unless($collection->dbID);
  #print("DnaCollectionAdaptor:store() dbID = ", $collection->dbID, "\n");

  my @dna_objects = @{$collection->get_all_dna_objects};
  $sth = $self->prepare("INSERT ignore INTO dna_collection (dna_collection_id, table_name, foreign_id) VALUES (?,?,?)");
  foreach my $object (@dna_objects) {
    if($object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunk')) {
      $sth->execute($collection->dbID, 'dnafrag_chunk', $object->dbID);
    }
    if($object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunkSet')) {
      $sth->execute($collection->dbID, 'dnafrag_chunk_set', $object->dbID);
    }
  }
  $sth->finish;

  $collection->adaptor($self);

  return $collection->dbID;
}


=head2 store_link

  Arg [1]    :  int $dna_collection_id
  Arg [2]    :  int $foreign_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub store_link {
  my ($self, $dna_collection_id, $foreign_id) = @_;

  return unless($dna_collection_id and $foreign_id);

  my $sth = $self->prepare("INSERT ignore INTO dna_collection (dna_collection_id, foreign_id) VALUES (?,?)");
  $sth->execute($dna_collection_id, $foreign_id);
  $sth->finish;
}


=head2 delete_link

  Arg [1]    :  int $dna_collection_id
  Arg [2]    :  int $foreign_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub delete_link {
  my ($self, $dna_collection_id, $foreign_id) = @_;

  my $sth = $self->prepare("DELETE FROM dna_collection WHERE dna_collection_id=? AND foreign_id=?");
  $sth->execute($dna_collection_id, $foreign_id);
  $sth->finish;
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
  my $constraint = "s.description = '$set_description'";
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

  return (['subset', 's'], ['dna_collection', 'dc']);
}

sub _columns {
  my $self = shift;

  return qw (s.subset_id
             s.description
             s.dump_loc
             dc.dna_collection_id
             dc.table_name
             dc.foreign_id);
}

sub _default_where_clause {
  my $self = shift;

  return 's.subset_id = dc.dna_collection_id';
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

#  print STDERR $sql,"\n";

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
                -dbid        => $column{'dna_collection_id'},
                -description => $column{'description'},
                -adaptor     => $self;
      $collections_hash->{$collection->dbID} = $collection;
    }

    if (defined($column{'dump_loc'})) {
      $collection->dump_loc($column{'dump_loc'});
    }
    if($column{'table_name'} eq 'dnafrag_chunk') {
      my $chunk = $chunkDBA->fetch_by_dbID($column{'foreign_id'});
      $collection->add_dna_object($chunk);
    }
    if($column{'table_name'} eq 'dnafrag_chunk_set') {
      my $chunk_set = $chunkSetDBA->fetch_by_dbID($column{'foreign_id'});
      $collection->add_dna_object($chunk_set);
    }
  }
  $sth->finish;

  my @collections = values(%{$collections_hash});

  return \@collections;
}


sub _fetch_all_DnaFragChunk_by_ids {
  my $self = shift;
  my $chunkID_list = shift;  #list reference

}

1;





