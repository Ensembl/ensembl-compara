package Bio::EnsEMBL::Compara::BaseRelationAdaptor;

use strict;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 generic_fetch

  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
  Arg [2]    : (optional) string $logic_name
               the logic_name of the analysis of the features to obtain
  Example    : $fts = $a->generic_fetch('contig_id in (1234, 1235)', 'Swall');
  Description: Performs a database fetch and returns feature objects in
               contig coordinates.
  Returntype : listref of Bio::EnsEMBL::SeqFeature in contig coordinates
  Exceptions : none
  Caller     : BaseFeatureAdaptor, ProxyDnaAlignFeatureAdaptor::generic_fetch

=cut
  
sub generic_fetch {
  my ($self, $constraint, $join, $extra_columns) = @_;
  
  my @tables = $self->_tables;
  my $columns = join(', ', $self->_columns());
  
  if ($join) {
    my ($tablename, $condition) = $join;
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

  return $self->_objs_from_sth($sth);
}

sub fetch_all {
  my $self = shift;

  return $self->generic_fetch();
}

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
  Returntype : Bio::EnsEMBL::SeqFeature
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
  my ($obj) = @{$self->generic_fetch($constraint)};
  return $obj;
}



=head2 fetch_by_stable_id

  Arg [1]    : string $stable_id
               the unique database identifier for the feature to be obtained
  Example    : $feat = $adaptor->fetch_by_dbID(1234);
  Description: Returns the feature created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::SeqFeature
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_by_stable_id{
  my ($self,$stable_id) = @_;

  unless(defined $stable_id) {
    $self->throw("fetch_by_stable_id must have an stable_id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${syn}.stable_id = $stable_id";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->generic_fetch($constraint)};
  return $obj;
}

=head2 fetch_by_source

=cut

sub fetch_by_source {
  my ($self,$source_name) = @_;

  $self->throw("source_name arg is required\n")
    unless ($source_name);

  my $constraint = "s.source_name = '$source_name'";

  return $self->generic_fetch($constraint);
}

sub store_source {
  my ($self,$source_name) = @_;
  
  my $sql = "SELECT source_id FROM source WHERE source_name = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($source_name);
  my $rowhash = $sth->fetchrow_hashref;
  if ($rowhash->{source_id}) {
    return $rowhash->{source_id};
  } else {
    $sql = "INSERT INTO source (source_name) VALUES (?)";
    $sth = $self->prepare($sql);
    $sth->execute($source_name);
    return $sth->{'mysql_insertid'};
  }
}

sub store_relation {
  my ($self, $member, $relation) = @_;

  my $member_adaptor = $self->db->get_MemberAdaptor;
  $member_adaptor->store($member);
  
  my $sql;

  if ($relation->isa('Bio::EnsEMBL::Compara::Family')) {
    $sql = "INSERT INTO family_member (family_id, member_id) VALUES (?,?)";
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
    $sql = "INSERT INTO domain_member (domain_id, member_id) VALUES (?,?)";
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
    $sql = "INSERT INTO homology_member (homology_id, member_id) VALUES (?,?)";
  }

  my $sth = $self->prepare($sql);
  $sth->execute($relation->dbID, $member->dbID);
}

sub known_sources {
  my ($self) = @_;
  
  my $q;
  if ($self->isa('Bio::EnsEMBL::Compara::FamilyAdaptor')) {
    $q = 
    "SELECT distinct(source_name) FROM source s,member m,family_member fm where s.source_id=m.source_id and m.member_id=fm.member_id";
  } elsif ($self->isa('Bio::EnsEMBL::Compara::DomainAdaptor')) {
    $q = 
    "SELECT distinct(source_name) FROM source s,member m,domain_member dm where s.source_id=m.source_id and m.member_id=dm.member_id";
  } elsif ($self->isa('Bio::EnsEMBL::Compara::HomologyAdaptor')) {
    $q = 
    "SELECT distinct(source_name) FROM source s,member m,homology_member hm where s.source_id=m.source_id and m.member_id=hm.member_id";
  }

  $q = $self->prepare($q);
  $q->execute;

  my @res= ();
  while ( my ( @row ) = $q->fetchrow_array ) {
        push @res, $row[0];
  }
  $self->throw("didn't find any source") if (int(@res) == 0);
  return \@res;
}

=head2 get_source_id_by_source_name

=cut

sub get_source_id_by_source_name {
  my ($self, $source_name) = @_;

  $self->throw("Should give a defined source_name as argument\n") 
    unless (defined $source_name);

  my $q = "SELECT source_id FROM source WHERE source_name = ?";
  $q = $self->prepare($q);
  $q->execute($source_name);
  my $rowhash = $q->fetchrow_hashref;

  return $rowhash->{source_id};
}

=head2 get_source_name_by_source_id

=cut

sub get_source_name_by_source_id {
  my ($self, $source_id) = @_;

  $self->throw("Should give a defined source_id as argument\n") 
    unless (defined $source_id);

  my $q = "SELECT source_name FROM source WHERE source_id = ?";
  $q = $self->prepare($q);
  $q->execute($source_id);
  my $rowhash = $q->fetchrow_hashref;

  return $rowhash->{source_name};
}
