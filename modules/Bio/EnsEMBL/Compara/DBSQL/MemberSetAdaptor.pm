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
  my $constraint = "ms.name = '$name'";

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

  return (['member_set', 'ms'], ['member_set_link', 'l']);
}

sub _columns {
  my $self = shift;

  return qw (ms.member_set_id
             ms.name
             l.member_set_id
             l.member_id);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @memberSets = ();
  my %setNames = {};
  my %setMemberIds = {};

  while ($sth->fetch()) {
    my ($member_set_id, $name);
    $member_set_id = $column{'ms.member_set_id'};
    $name = $column{'ms.name'};
    $member_id = $column{'l.member_id'}

    if(not defined($setNames{$member_set_id})) {
      $setNames{$member_set_id} = $name;
      $setMemberIds{$member_set_id} = ($member_id);
    }
    else {
      push $setMemberIds{$member_set_id}, $member_id;
    }
  }

  @memberSetIds = keys(%setNames);
  foreach $member_set_id (@memberSetIds) {
    my ($memberSet);

    @member_id_list = $setMemberIds{$member_set_id};
    
    $memberSet = Bio::EnsEMBL::Compara::MemberSet->new_fast
      ({'_dbID' => $member_set_id,
        '_name' => $setNames{$member_set_id},
        '_member_id_list' => @member_id_list;
        '_adaptor' => $self});

    push @memberSets, $memberSet;

  }
  return \@memberSets
}

sub _default_where_clause {
  my $self = shift;

  return 'ms.member_set_id = l.member_set_id';
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


  return $memberSet->dbID;
}


1;





