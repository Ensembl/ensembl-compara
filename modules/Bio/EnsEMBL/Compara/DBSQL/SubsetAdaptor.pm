package Bio::EnsEMBL::Compara::DBSQL::SubsetAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Compara::Subset;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 fetch_by_dbID

  Arg [1]    : int $id
               the unique database identifier for the feature to be obtained
  Example    : $feat = $adaptor->fetch_by_dbID(1234);
  Description: Returns the feature created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::Compara::Subset
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
    $self->throw("fetch_by_set_name must have a set_description");
  }

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "s.description = '$set_description'";
  print("fetch_by_set_name contraint:\n$constraint\n");

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

  return (['subset', 's'], ['subset_member', 'sm']);
}

sub _columns {
  my $self = shift;

  return qw (s.subset_id
             s.description
             sm.subset_id
             sm.member_id);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @sets = ();
  my %setNames;
  my %setMemberIds;

  while ($sth->fetch()) {
    my ($subset_id, $name, $member_id);
    $subset_id = $column{'subset_id'};
    $name = $column{'description'};
    $member_id = $column{'member_id'};

    if(defined($setMemberIds{$subset_id})) {
      $setMemberIds{$subset_id}->{$member_id} = $member_id;
    }
    else {
      $setNames{$subset_id} = $name;
      $setMemberIds{$subset_id} = {};
      $setMemberIds{$subset_id}->{$member_id} = $member_id;
    }
  }
  $sth->finish;

  my @allSubsetIds = keys(%setNames);

  foreach my $subset_id (@allSubsetIds) {
    my ($subset, @member_id_list, $member_id);

    @member_id_list = keys(%{$setMemberIds{$subset_id}});
    my $count = $#member_id_list + 1;
    # print("subset id = $subset_id has $count unique member_ids\n");
    
    $subset = Bio::EnsEMBL::Compara::Subset->new(-dbid => $subset_id,
                                                 -name => $setNames{$subset_id},
                                                 -adaptor => $self);
    # print("loading set '" . $setNames{$subset_id} . "' id=$subset_id\n");

    @{$subset->{'_member_id_list'}} = @member_id_list;

    push @sets, $subset;
  }

  return \@sets
}

sub _default_where_clause {
  my $self = shift;

  return 's.subset_id = sm.subset_id';
}

sub _final_clause {
  my $self = shift;

  return '';
}


#
# STORE METHODS
#
################

=head2 store

  Arg [1]    :
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub store {
  my ($self,$subset) = @_;

  unless($subset->isa('Bio::EnsEMBL::Compara::Subset')) {
    $self->throw(
      "set arg must be a [Bio::EnsEMBL::Compara::Subset] "
    . "not a $subset");
  }

  my $sth = $self->prepare("INSERT ignore INTO subset (description) VALUES (?)");
  if($sth->execute($subset->description) >0) {
    $subset->dbID( $sth->{'mysql_insertid'} );
  } else {
    #print("insert failed, do select\n");
    my $sth2 = $self->prepare("SELECT subset_id FROM subset WHERE description=?");
    $sth2->execute($subset->description);
    my($id) = $sth2->fetchrow_array();
    $subset->dbID($id);
    $sth2->finish;
  }
  $sth->finish;
  #print("SubsetAdaptor:store() dbID = ", $subset->dbID, "\n");

  my @memberIds = @{$subset->member_id_list()};
  $sth = $self->prepare("INSERT ignore INTO subset_member (subset_id, member_id) VALUES (?,?)");
  foreach my $member_id (@memberIds) {
    $sth->execute($subset->dbID, $member_id) if($member_id);
  }
  $sth->finish;

  $subset->adaptor($self);

  return $subset->dbID;
}


=head2 store_link

  Arg [1]    :  Bio::EnsEMBL::Compara::MemberSet $subset
  Arg [2]    :  int $member_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub store_link {
  my ($self, $subset, $member_id) = @_;

  unless($subset->isa('Bio::EnsEMBL::Compara::Subset')) {
    $self->throw(
      "set arg must be a [Bio::EnsEMBL::Compara::Subset] "
    . "not a $subset");
  }
  return unless($member_id);

  my $sth = $self->prepare("INSERT ignore INTO subset_member (subset_id, member_id) VALUES (?,?)");
  $sth->execute($subset->dbID, $member_id);
  $sth->finish;
}


=head2 delete_link

  Arg [1]    :  Bio::EnsEMBL::Compara::MemberSet $subset
  Arg [2]    :  int $member_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub delete_link {
  my ($self, $subset, $member_id) = @_;

  unless($subset->isa('Bio::EnsEMBL::Compara::Subset')) {
    $self->throw(
      "set arg must be a [Bio::EnsEMBL::Compara::Subset] "
    . "not a $subset");
  }

  my $sth =
    $self->prepare("DELETE FROM subset_member WHERE subset_id=? AND member_id=?");
  $sth->execute($subset->dbID, $member_id);
  $sth->finish;
}


sub dumpFastaForSubset {
  my($self, $subset, $fastafile) = @_;

  unless($subset->isa('Bio::EnsEMBL::Compara::Subset')) {
    $self->throw(
      "set arg must be a [Bio::EnsEMBL::Compara::Subset] "
    . "not a $subset");
  }
  unless($subset->dbID) {
    $self->throw("subset must be in database and dbID defined");
  }
  
  my $sql = "SELECT member.source_name, member.stable_id, member.genome_db_id," .
            " member.member_id, member.description, sequence.sequence " .
            " FROM member, sequence, subset_member " .
            " WHERE subset_member.subset_id = " . $subset->dbID .
            " AND member.member_id=subset_member.member_id ".
            " AND member.sequence_id=sequence.sequence_id " ;
           # " ORDER BY member.stable_id;";

  open FASTAFILE, ">$fastafile"
    or die "Could open $fastafile for output\n";
  print("writing fasta to loc '$fastafile'\n");

  my $sth = $self->prepare( $sql );
  $sth->execute();

  my ($source_name, $stable_id, $genome_db_id, $member_id, $description, $sequence);
  $sth->bind_columns( undef, \$source_name, \$stable_id, \$genome_db_id,
      \$member_id, \$description, \$sequence );

  while( $sth->fetch() ) {
    $sequence =~ s/(.{72})/$1\n/g;
    $genome_db_id ||= 0;
    print FASTAFILE ">$source_name:$stable_id IDs:$genome_db_id:$member_id $description\n$sequence\n";
  }
  close(FASTAFILE);

  $sth->finish();

  #
  # update this subset_id's  subset.dump_loc with the full path of this dumped fasta file
  #

  $sth = $self->prepare("UPDATE subset SET dump_loc = ? WHERE subset_id = ?");
  $sth->execute($fastafile, $subset->dbID);
  $sth->finish;
  $subset->dump_loc($fastafile);
}

1;





