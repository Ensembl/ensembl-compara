package Bio::EnsEMBL::Compara::DBSQL::MemberSetAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 list_internal_ids

  Arg        : None
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub list_internal_ids {
  my $self = shift;
  
  my @tables = $self->_tables;
  my ($name, $syn) = @{$tables[0]};
  my $sql = "SELECT ${syn}.${name}_id from ${name} ${syn}";
  
  my $sth = $self->prepare($sql);
  $sth->execute;  
  
  my $internal_id;
  $sth->bind_columns(\$internal_id);

  my @internal_ids;
  while ($sth->fetch()) {
    push @internal_ids, $internal_id;
  }

  $sth->finish;

  return \@internal_ids;
}

=head2 fetch_by_dbID

  Arg [1]    : int $id
               the unique database identifier for the feature to be obtained
  Example    : $feat = $adaptor->fetch_by_dbID(1234);
  Description: Returns the feature created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::Compara::MemberSet
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

=head2 fetch_by_set_name

  Arg [1]    : string $member_set_name
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_by_set_name {
  my ($self,$member_set_name) = @_;

  unless(defined $member_set_name) {
    $self->throw("fetch_by_set_name must have a member_set_name");
  }

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "m.name = '$member_set_name'";

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

  return (['member_set', 'm'], ['member_set_link', 'l']);
}

sub _columns {
  my $self = shift;

  return qw (m.member_set_id
             m.name
             l.member_set_id
             l.member_id);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @memberSets = ();
  my %setNames;
  my %setMemberIds;
  my $MemberAdapter = $self->db->get_MemberAdaptor;

  while ($sth->fetch()) {
    my ($member_set_id, $name, $member_id);
    $member_set_id = $column{'m.member_set_id'};
    $name = $column{'m.name'};
    $member_id = $column{'l.member_id'};

    if(defined($setMemberIds{$member_set_id})) {
      push @{$setMemberIds{$member_set_id}}, $member_id;
    }
    else {
      $setNames{$member_set_id} = $name;
      $setMemberIds{$member_set_id} = [$member_id];
    }
  }

  my @allMemberSetIds = keys(%setNames);
  foreach my $member_set_id (@allMemberSetIds) {
    my ($memberSet, @member_id_list, $member_id);

    @member_id_list = $setMemberIds{$member_set_id};
    
    $memberSet = Bio::EnsEMBL::Compara::MemberSet->new_fast
        ({'_dbID' => $member_set_id,
          '_name' => $setNames{$member_set_id},
          '_adaptor' => $self});

    foreach $member_id (@{$setMemberIds{$member_set_id}}) {
      #$memberSet->add_member_id($member_id);

      my $member = $MemberAdapter->fetch_by_dbID($member_id);
      $memberSet->add_member($member);
    }

    push @memberSets, $memberSet;
  }
  return \@memberSets
}

sub _default_where_clause {
  my $self = shift;

  return 'm.member_set_id = l.member_set_id';
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
  my ($self,$memberSet) = @_;

  unless($memberSet->isa('Bio::EnsEMBL::Compara::MemberSet')) {
    $self->throw(
      "member_set arg must be a [Bio::EnsEMBL::Compara::MemberSet] "
    . "not a $memberSet");
  }
  
  my $sth =
    $self->prepare("INSERT INTO member_set (name)
                    VALUES (?)");

  $sth->execute($memberSet->name);
  $memberSet->dbID( $sth->{'mysql_insertid'} );

  my @memberIds = @{$memberSet->member_id_list()};
  foreach my $member_id (@memberIds) {
    my $sth =
      $self->prepare("INSERT INTO member_set_link (member_set_id, member_id)
                      VALUES (?,?)");
    $sth->execute($memberSet->dbID, $member_id);
  }

  $memberSet->adaptor($self);
  
  return $memberSet->dbID;
}


=head2 store_link

  Arg [1]    :  Bio::EnsEMBL::Compara::MemberSet $memberSet
  Arg [2]    :  int $member_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub store_link {
  my ($self, $memberSet, $member_id) = @_;

  unless($memberSet->isa('Bio::EnsEMBL::Compara::MemberSet')) {
    $self->throw(
      "member_set arg must be a [Bio::EnsEMBL::Compara::MemberSet] "
    . "not a $memberSet");
  }

  my $sth =
    $self->prepare("INSERT INTO member_set_link (member_set_id, member_id)
                    VALUES (?,?)");
  $sth->execute($memberSet->dbID, $member_id);
}


1;





