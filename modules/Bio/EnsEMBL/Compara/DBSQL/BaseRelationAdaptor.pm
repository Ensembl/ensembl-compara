package Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

use strict;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 generic_fetch

  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
               e.g. "fm.family_id = $family_id"
  Arg [2]    : (optional) arrayref $join
               the arrayref $join should contain arrayrefs of this form
               [['family_member', 'fm'],
                # the table to join with synonym (mandatory) as an arrayref
                'm.member_id = fm.member_id',
                # the join condition (mandatory)
                [qw(fm.family_id fm.member_id fm.cigar_line)]]
                # any additional columns that the join could imply (optional)
                # as an arrayref
  Example    : $arrayref = $a->generic_fetch($constraint, $join);
  Description: Performs a database fetch and returns BaseRelation-inherited objects
  Returntype : arrayref of Bio::EnsEMBL::Compara::BaseRelation-inherited objects
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor::generic_fetch_sth

=cut
   
sub generic_fetch {
  my ($self, $constraint, $join) = @_;

  my $sth = $self->generic_fetch_sth($constraint, $join);

  return $self->_objs_from_sth($sth);
  
}

=head2 generic_fetch_sth

  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
               e.g. "fm.family_id = $family_id"
  Arg [2]    : (optional) arrayref $join
               the arrayref $join should contain arrayrefs of this form
               [['family_member', 'fm'],
                # the table to join with synonym (mandatory) as an arrayref
                'm.member_id = fm.member_id',
                # the join condition (mandatory)
                [qw(fm.family_id fm.member_id fm.cigar_line)]]
                # any additional columns that the join could imply (optional)
                # as an arrayref 
  Example    : $sth = $a->generic_fetch_sth($constraint, $join);
  Description: Performs a database fetch and returns the SQL state handle
  Returntype : DBI::st
  Exceptions : none
  Caller     : BaseFeatureAdaptor, ProxyDnaAlignFeatureAdaptor::generic_fetch

=cut
  
sub generic_fetch_sth {
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

#  print STDERR $sql,"\n";

  $sth->execute;  

  return $sth;
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

sub fetch_by_stable_id {
  my ($self,$stable_id) = @_;

  unless(defined $stable_id) {
    $self->throw("fetch_by_stable_id must have an stable_id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${syn}.stable_id = '$stable_id'";

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
  my ($self, $member_attribute, $relation) = @_;

  my ($member, $attribute) = @{$member_attribute};
  my $member_adaptor = $self->db->get_MemberAdaptor;
  $member_adaptor->store($member);
  $attribute->member_id($member->dbID);

  my $sql;
  my $sth;
  
  if ($relation->isa('Bio::EnsEMBL::Compara::Family')) {
    $attribute->family_id($relation->dbID);
    $sql = "INSERT INTO family_member (family_id, member_id, cigar_line) VALUES (?,?,?)";
    $sth = $self->prepare($sql);
    $sth->execute($attribute->family_id, $attribute->member_id, $attribute->cigar_line);
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
    $attribute->domain_id($relation->dbID);
    $sql = "INSERT INTO domain_member (domain_id, member_id, member_start, member_end) VALUES (?,?,?,?)";
    $sth = $self->prepare($sql);
    $sth->execute($attribute->domain_id, $attribute->member_id, $attribute->member_start, $attribute->member_end);
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
    $attribute->homology_id($relation->dbID);
    $sql = "INSERT INTO homology_member (homology_id, member_id, cigar_line, perc_cov, perc_id, perc_pos, flag) VALUES (?,?,?,?,?,?,?)";
    $sth = $self->prepare($sql);
    $sth->execute($attribute->homology_id, $attribute->member_id, $attribute->cigar_line, $attribute->perc_cov, $attribute->perc_id, $attribute->perc_pos, $attribute->flag);
  }
}

sub update_relation {
  my ($self, $member_attribute) = @_;

  my ($member, $attribute) = @{$member_attribute};
  my $sql;
  my $sth;
 
  if (defined $attribute->family_id) {
    $sql = "UPDATE family_member SET cigar_line = ? WHERE family_id = ? AND member_id = ?";
    $sth = $self->prepare($sql);
    $sth->execute($attribute->cigar_line, $attribute->family_id, $attribute->member_id);
  } else {
    $self->throw("update_relation only implemented for family relation, but you have either a domain or homology relation\n");
  }
}

sub _known_sources {
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


=head2 _tables

  Args       : none
  Example    : $tablename = $self->_table_name()
  Description: ABSTRACT PROTECTED Subclasses are responsible for implementing
               this method.  It should list of [tablename, alias] pairs.
               Additionally the primary table (with the dbID, analysis_id, and
               score) should be the first table in the list.
               e.g:
               ( ['repeat_feature',   'rf'],
                 ['repeat_consensus', 'rc']);
               used to obtain features.
  Returntype : list of [tablename, alias] pairs
  Exceptions : thrown if not implemented by subclass
  Caller     : BaseFeatureAdaptor::generic_fetch

=cut

sub _tables {
  my $self = shift;

  $self->throw("abstract method _tables not defined by implementing" .
               " subclass of BaseFeatureAdaptor");
  return undef;
}


=head2 _columns

  Args       : none
  Example    : $tablename = $self->_columns()
  Description: ABSTRACT PROTECTED Subclasses are responsible for implementing
               this method.  It should return a list of columns to be used
               for feature creation
  Returntype : list of strings
  Exceptions : thrown if not implemented by subclass
  Caller     : BaseFeatureAdaptor::generic_fetch

=cut

sub _columns {
  my $self = shift;

  $self->throw("abstract method _columns not defined by implementing" .
               " subclass of BaseFeatureAdaptor");
}

=head2 _objs_from_sth

  Arg [1]    : DBI::row_hashref $hashref containing key-value pairs
               for each of the columns specified by the _columns method
  Example    : my @feats = $self->_obj_from_hashref
  Description: ABSTRACT PROTECTED The subclass is responsible for implementing
               this method.  It should take in a DBI row hash reference and
               return a list of created features in contig coordinates.
  Returntype : list of Bio::EnsEMBL::*Features in contig coordinates
  Exceptions : thrown if not implemented by subclass
  Caller     : BaseFeatureAdaptor::generic_fetch

=cut

sub _objs_from_sth {
  my $self = shift;

  $self->throw("abstract method _obj_from_sth not defined by implementing"
             . " subclass of BaseFeatureAdaptor");
}

=head2 _join

  Arg [1]    : none
  Example    : none
  Description: Can be overridden by a subclass to specify any left joins
               which should occur. The table name specigfied in the join
               must still be present in the return values of
  Returntype : a {'tablename' => 'join condition'} pair
  Exceptions : none
  Caller     : general

=cut

sub _join {
  my $self = shift;

  return '';
}

=head2 _default_where_clause

  Arg [1]    : none
  Example    : none
  Description: May be overridden to provide an additional where constraint to
               the SQL query which is generated to fetch feature records.
               This constraint is always appended to the end of the generated
               where clause
  Returntype : string
  Exceptions : none
  Caller     : generic_fetch

=cut

sub _default_where_clause {
  my $self = shift;

  return '';
}

=head2 _final_clause

  Arg [1]    : none
  Example    : none
  Description: May be overriden to provide an additional clause to the end
               of the SQL query used to fetch feature records.
               This is useful to add a required ORDER BY clause to the
               query for example.
  Returntype : string
  Exceptions : none
  Caller     : generic_fetch

=cut

sub _final_clause {
  my $self = shift;

  return '';
}

