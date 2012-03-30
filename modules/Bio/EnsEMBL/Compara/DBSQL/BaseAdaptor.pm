package Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;

use strict;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::DBSQL::BaseAdaptor');


sub attach {
    my ($self, $object, $dbID) = @_;

    $object->adaptor( $self );
    return $object->dbID( $dbID );
}


sub left_join_clause {
    my $self = shift @_;

    if(@_) {
        $self->{'ljc'} = shift @_;
    }

    return $self->{'ljc'} || '';
}


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

  my $sql  = "SELECT $columns FROM $tablenames ".$self->left_join_clause;

  my $default_where = $self->_default_where_clause;

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
  $sql .= ' '.$self->_final_clause;

  my $sth = $self->prepare($sql);

#  warn $sql;

  $sth->execute();
  my $obj_list = $self->_objs_from_sth($sth);
  $sth->finish();

  return $obj_list;
}


1;

