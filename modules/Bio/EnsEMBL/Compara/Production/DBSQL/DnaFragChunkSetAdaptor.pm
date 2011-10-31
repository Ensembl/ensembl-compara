package Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkSetAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


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

  unless($chunkSet->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunkSet')) {
    $self->throw(
      "set arg must be a [Bio::EnsEMBL::Compara::Production::DnaFragChunkSet] "
    . "not a $chunkSet");
  }

  my $sth;
  my $insertCount=0;

  if(defined($chunkSet->description)) {
    $sth = $self->prepare("INSERT ignore INTO subset (description) VALUES (?)");
    $insertCount = $sth->execute($chunkSet->description);
  } else {
    $sth = $self->prepare("INSERT ignore INTO subset SET description=NULL");
    $insertCount = $sth->execute();
  }

  if($insertCount>0) {
    $chunkSet->dbID( $sth->{'mysql_insertid'} );
  }
  else {
    #print("insert failed, do select\n");
    my $sth2 = $self->prepare("SELECT subset_id FROM subset WHERE description=?");
    $sth2->execute($chunkSet->description);
    my($id) = $sth2->fetchrow_array();
    $chunkSet->dbID($id);
    $sth2->finish;
  }
  $sth->finish;
  #print("DnaFragChunkSetAdaptor:store() dbID = ", $chunkSet->dbID, "\n");

  my @dnafrag_chunkIds = @{$chunkSet->dnafrag_chunk_ids()};
  $sth = $self->prepare("INSERT ignore INTO dnafrag_chunk_set (subset_id, dnafrag_chunk_id) VALUES (?,?)");
  foreach my $dnafrag_chunk_id (@dnafrag_chunkIds) {
    $sth->execute($chunkSet->dbID, $dnafrag_chunk_id) if($dnafrag_chunk_id);
  }
  $sth->finish;

  $chunkSet->adaptor($self);

  return $chunkSet->dbID;
}


=head2 store_link

  Arg [1]    :  int $subset_id
  Arg [2]    :  int $dnafrag_chunk_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub store_link {
  my ($self, $subset_id, $dnafrag_chunk_id) = @_;

  return unless($subset_id and $dnafrag_chunk_id);

  my $sth = $self->prepare("INSERT ignore INTO dnafrag_chunk_set (subset_id, dnafrag_chunk_id) VALUES (?,?)");
  $sth->execute($subset_id, $dnafrag_chunk_id);
  $sth->finish;
}


=head2 delete_link

  Arg [1]    :  int $subset_id
  Arg [2]    :  int $dnafrag_chunk_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub delete_link {
  my ($self, $subset_id, $dnafrag_chunk_id) = @_;

  my $sth = $self->prepare("DELETE FROM dnafrag_chunk_set WHERE subset_id=? AND dnafrag_chunk_id=?");
  $sth->execute($subset_id, $dnafrag_chunk_id);
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
  Returntype : Bio::EnsEMBL::Compara::Production::DnaFragChunkSet
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_by_dbID{
  my ($self,$id) = @_;

  unless(defined $id) {
    $self->throw("fetch_by_dbID must have an id");
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
    $self->throw("fetch_by_set_description must have a description");
  }

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "s.description = '$set_description'";
  #print("fetch_by_set_name contraint:\n$constraint\n");

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}

=head2 fetch_all

  Arg        : None
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_all {
  my $self = shift;

  return $self->_generic_fetch();
}



#
# INTERNAL METHODS
#
###################

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

sub _tables {
  my $self = shift;

  return (['subset', 's'], ['dnafrag_chunk_set', 'sc']);
}

sub _columns {
  my $self = shift;

  return qw (s.subset_id
             s.description
             s.dump_loc
             sc.subset_id
             sc.dnafrag_chunk_id);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @sets = ();
  my %setNames;
  my %setDnaFragChunkIds;

  while ($sth->fetch()) {
    my ($subset_id, $name, $dnafrag_chunk_id);
    $subset_id = $column{'subset_id'};
    $name = $column{'description'};
    $dnafrag_chunk_id = $column{'dnafrag_chunk_id'};

    if(defined($setDnaFragChunkIds{$subset_id})) {
      $setDnaFragChunkIds{$subset_id}->{$dnafrag_chunk_id} = $dnafrag_chunk_id;
    }
    else {
      $setNames{$subset_id} = $name;
      $setDnaFragChunkIds{$subset_id} = {};
      $setDnaFragChunkIds{$subset_id}->{$dnafrag_chunk_id} = $dnafrag_chunk_id;
    }
  }
  $sth->finish;

  my @allSubsetIds = keys(%setNames);

  foreach my $subset_id (@allSubsetIds) {
    my ($chunkSet, @dnafrag_chunk_id_list, $dnafrag_chunk_id);

    @dnafrag_chunk_id_list = keys(%{$setDnaFragChunkIds{$subset_id}});
    my $count = scalar(@dnafrag_chunk_id_list);
    # print("chunkSet id = $subset_id has $count unique dnafrag_chunk_ids\n");
    
    $chunkSet = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet
                  -dbid => $subset_id,
                  -name => $setNames{$subset_id},
                  -adaptor => $self;
    # print("loading set '" . $setNames{$subset_id} . "' id=$subset_id\n");

    @{$chunkSet->{'_dnafrag_chunk_id_list'}} = @dnafrag_chunk_id_list;

    push @sets, $chunkSet;
  }

  return \@sets
}

sub _default_where_clause {
  my $self = shift;

  return 's.subset_id = sc.subset_id';
}

sub _final_clause {
  my $self = shift;

  return '';
}

sub _fetch_all_DnaFragChunk_by_ids {
  my $self = shift;
  my $chunkID_list = shift;  #list reference

  return $self->db->get_DnaFragChunkAdaptor->fetch_by_dbIDs(@$chunkID_list);
}

1;





