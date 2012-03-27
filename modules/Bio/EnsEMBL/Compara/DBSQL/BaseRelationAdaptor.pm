package Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

use strict;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::DBSQL::BaseAdaptor');


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
  Caller     : various adaptors' specific fetch_ subroutines

=cut
  
sub generic_fetch {
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

#  warn $sql;

  $sth->execute;
  my $obj_list = $self->_objs_from_sth($sth);
  $sth->finish();

  return $obj_list;
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

sub fetch_by_dbID {
  my ($self, $id) = @_;

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
  Exceptions : thrown if $stable_id is not defined
  Caller     : general

=cut

sub fetch_by_stable_id {
  my ($self, $stable_id) = @_;

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


sub fetch_all_by_method_link_type {
  my ($self, $method_link_type) = @_;

  $self->throw("method_link_type arg is required\n")
    unless ($method_link_type);

  my $mlss_arrayref = $self->db->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type($method_link_type);

  unless (scalar @{$mlss_arrayref}) {
    warning("There is no $method_link_type data stored in the database\n");
    return [];
  }
  
  my @tabs = $self->_tables;
  my ($name, $syn) = @{$tabs[0]};

  my $constraint =  " ${syn}.method_link_species_set_id in (". join (",", (map {$_->dbID} @{$mlss_arrayref})) . ")";

  return $self->generic_fetch($constraint);
}


sub store_relation {
  my ($self, $member_attribute, $relation) = @_;

  my ($member, $attribute) = @{$member_attribute};
  my $member_adaptor = $self->db->get_MemberAdaptor;
  unless (defined $member->dbID) {
    $member_adaptor->store($member);
  }
  $attribute->member_id($member->dbID);

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


1;
