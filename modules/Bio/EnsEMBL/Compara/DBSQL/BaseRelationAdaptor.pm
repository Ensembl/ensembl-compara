package Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

use strict;
use Bio::EnsEMBL::Utils::Exception;
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

#  warn $sql;

  $sth->execute;

  return $sth;
}

sub fetch_all {
  my $self = shift;

  return $self->generic_fetch();
}


sub list_dbIDs {
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
  deprecate("Calling $self->fetch_all_by_method_link_type instead\n");

  return $self->fetch_all_by_method_link_type($source_name);
}

sub fetch_all_by_method_link_type {
  my ($self,$method_link_type) = @_;

  $self->throw("method_link_type arg is required\n")
    unless ($method_link_type);

  my $mlss_arrayref = $self->db->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type($method_link_type);

  unless (scalar @{$mlss_arrayref}) {
    warning("There is no $method_link_type data stored in the database\n");
    return [];
  }
  
  my $constraint = "";

  if ($self->isa('Bio::EnsEMBL::Compara::Homology')) {
    $constraint .=  " h.method_link_species_set_id in (". join (",", (map {$_->dbID} @{$mlss_arrayref})) . ")";

  } elsif ($self->isa('Bio::EnsEMBL::Compara::Family')) {
    $constraint .=  " f.method_link_species_set_id in (". join (",", (map {$_->dbID} @{$mlss_arrayref})) . ")";

  } elsif ($self->isa('Bio::EnsEMBL::Compara::Domain')) {
    $constraint .=  " d.method_link_species_set_id in (". join (",", (map {$_->dbID} @{$mlss_arrayref})) . ")";

  }

  return $self->generic_fetch($constraint);
}

sub store_source {
  my ($self,$source_name) = @_;
  deprecate("store_source method is deprecated. Now this data has to be pre-stored in method_link table\n");
}

sub store_relation {
  my ($self, $member_attribute, $relation) = @_;

  my ($member, $attribute) = @{$member_attribute};
  my $member_adaptor = $self->db->get_MemberAdaptor;
  unless (defined $member->dbID) {
    $member_adaptor->store($member);
  }
  $attribute->member_id($member->dbID);

  my $sql;
  my $sth;
  
  if ($relation->isa('Bio::EnsEMBL::Compara::Family')) {
    $attribute->family_id($relation->dbID);
    $sql = "INSERT IGNORE INTO family_member (family_id, member_id, cigar_line) VALUES (?,?,?)";
    $sth = $self->prepare($sql);
    $sth->execute($attribute->family_id, $attribute->member_id, $attribute->cigar_line);
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
    $attribute->domain_id($relation->dbID);
    $sql = "INSERT IGNORE INTO domain_member (domain_id, member_id, member_start, member_end) VALUES (?,?,?,?)";
    $sth = $self->prepare($sql);
    $sth->execute($attribute->domain_id, $attribute->member_id, $attribute->member_start, $attribute->member_end);
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
    $attribute->homology_id($relation->dbID);
#     $sql = "INSERT IGNORE INTO homology_member (homology_id, member_id, peptide_member_id, cigar_line, cigar_start, cigar_end, perc_cov, perc_id, perc_pos, peptide_align_feature_id) VALUES (?,?,?,?,?,?,?,?,?,?)";
    $sql = "INSERT IGNORE INTO homology_member (homology_id, member_id, peptide_member_id, cigar_line, cigar_start, cigar_end, perc_cov, perc_id, perc_pos) VALUES (?,?,?,?,?,?,?,?,?)";
    $sth = $self->prepare($sql);
#     $sth->execute($attribute->homology_id, $attribute->member_id, $attribute->peptide_member_id, $attribute->cigar_line, $attribute->cigar_start, $attribute->cigar_end, $attribute->perc_cov, $attribute->perc_id, $attribute->perc_pos, $attribute->peptide_align_feature_id);
    $sth->execute($attribute->homology_id, $attribute->member_id, $attribute->peptide_member_id, $attribute->cigar_line, $attribute->cigar_start, $attribute->cigar_end, $attribute->perc_cov, $attribute->perc_id, $attribute->perc_pos);
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

# DEPRECATED METHODS
####################

sub _known_sources {
  my ($self) = @_;
  deprecate("_know_sources method is deprecated.\n");
}

sub get_source_id_by_source_name {
  my ($self, $source_name) = @_;
  throw("get_source_id_by_source_name method is deprecated\n");
}

sub get_source_name_by_source_id {
  my ($self, $source_id) = @_;
  throw("get_source_name_by_source_id method is deprecated\n");
}

sub list_internal_ids {
  my $self = shift;

  deprecate("list_internal_ids is deprecated. Calling list_dbIDs instead.\n");
  return $self->list_dbIDs;
}

1;
