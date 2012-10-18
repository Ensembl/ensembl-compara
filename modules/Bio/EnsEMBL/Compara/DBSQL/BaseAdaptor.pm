package Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;

use strict;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::DBSQL::BaseAdaptor');


sub attach {
    my ($self, $object, $dbID) = @_;

    $object->adaptor( $self );
    return $object->dbID( $dbID );
}


=head2 construct_sql_query

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
  Arg [3]    : (optional) string $final_clause
               Additional clause to the end of the SQL query used to fetch feature
               records. This is useful to add a required ORDER BY or LIMIT clause
               to the query for example. This argument overrides the return value
               of $self->_final_clause()
  Example    : $sql = $a->construct_sql_query($constraint, $join);
  Description: Builds a personalized SQL query that can be used to fetch the data.
  Returntype : String
  Exceptions : none
  Caller     : almost only generic_fetch()

=cut
  
sub construct_sql_query {
    my ($self, $constraint, $join, $final_clause) = @_;

    my @tabs = $self->_tables;
    my $columns = join(', ', $self->_columns());

    if ($join) {
        foreach my $single_join (@{$join}) {
            my ($tablename, $condition, $extra_columns) = @{$single_join};
            if ($tablename && $condition) {
                push @tabs, $tablename;

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

    #
    # Construct a left join statement if one was defined, and remove the
    # left-joined table from the table list
    #
    my @left_join_list = $self->_left_join();
    my $left_join_prefix = '';
    my $left_join = '';
    my @tables;
    if(@left_join_list) {
        my %left_join_hash = map { $_->[0] => $_->[1] } @left_join_list;
        while(my $t = shift @tabs) {
            my $t_alias = $t->[0] . " " . $t->[1];
            if( exists $left_join_hash{ $t->[0] } || exists $left_join_hash{$t_alias}) {
                my $condition = $left_join_hash{ $t->[0] };
                $condition ||= $left_join_hash{$t_alias};
                my $syn = $t->[1];
                $left_join .= " LEFT JOIN " . $t->[0] . " $syn ON $condition)";
                $left_join_prefix .= '(';
            } else {
                push @tables, $t;
            }
        }
    } else {
        @tables = @tabs;
    }

    #construct a nice table string like 'table1 t1, table2 t2'
    my $tablenames = join(', ', map({ join(' ', @$_) } @tables));

    my $sql  = "SELECT $columns FROM $left_join_prefix ($tablenames) $left_join";

    #append a where clause if it was defined
    my $default_where = $self->_default_where_clause;
    if($constraint) { 
        $sql .= " WHERE $constraint";
        if($default_where) {
            $sql .= " AND $default_where";
        }
    } elsif($default_where) {
        $sql .= " WHERE $default_where";
    }

    #append additional clauses which may have been defined
    if ($final_clause) {
        $sql .= ' '.$final_clause;
    } else {
        $sql .= ' '.$self->_final_clause;
    }

    #warn "$sql\n";
    return $sql;
}


=head2 generic_fetch
  Arguments  : Same arguments as construct_sql_query()
  Example    : $arrayref = $a->generic_fetch($constraint, $join, $final_clause);
  Description: Performs a database fetch and returns the newly created objects
  Returntype : arrayref of objects
  Exceptions : none
  Caller     : various adaptors' specific fetch_ subroutines
=cut
 
sub generic_fetch {
    my $self = shift;
    my $sql = $self->construct_sql_query(@_);
    my $sth = $self->prepare($sql);

    my $bind_parameters = $self->bind_param_generic_fetch();
    if (defined $bind_parameters){
        #if we have bind the parameters, call the DBI to bind them
        my $i = 1;
        foreach my $param (@{$bind_parameters}){
            $sth->bind_param($i,$param->[0],$param->[1]);
            $i++;
        }   
        #after binding parameters, undef for future queries
        $self->{'_bind_param_generic_fetch'} = (); 
    }
    eval { $sth->execute() };
    if ($@) {
        throw("Detected an error whilst executing SQL '${sql}': $@");
    }

    my $obj_list = $self->_objs_from_sth($sth);
    $sth->finish;
    return $obj_list;
}


=head2 generic_fetch_one
  Arguments  : Same arguments as construct_sql_query()
  Example    : $obj = $a->generic_fetch_one($constraint, $join, $final_clause);
  Description: Performs a database fetch and returns the first newly created object
  Returntype : object
  Exceptions : none
  Caller     : various adaptors' specific fetch_ subroutines
=cut
 
sub generic_fetch_one {
    my ($self, $constraint, $join, $final_clause) = @_;

    if (not defined $final_clause) {
        $final_clause = ' LIMIT 1';
    } elsif ($final_clause !~ m/ limit /i) {
        $final_clause .= ' LIMIT 1';
    }

    my $arr = $self->generic_fetch($constraint, $join, $final_clause);
    if (scalar(@$arr)) {
        return $arr->[0];
    } else {
        return undef;
    }
}


=head2 generic_fetch_Iterator
  Arg [1]    : (optional) integer $cache_size
               The number of dbIDs in each chunk (default: 1000)
  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
               e.g. "fm.family_id = $family_id"
  Example    : $obj = $a->generic_fetch_Iterator(100, 'WHERE taxon_id = 9606');
  Description: Performs a database fetch and returns an iterator over it
  Returntype : Bio::EnsEMBL::Utils::Iterator
  Exceptions : none
  Caller     : various adaptors' specific fetch_ subroutines
=cut

sub generic_fetch_Iterator {
    my ($self, $cache_size, $constraint) = @_;

    my ($name, $syn) = @{($self->_tables)[0]};
    # Fetch all the dbIDs
    my $sql = "SELECT ${name}.${name}_id FROM ${name}";
    if ($constraint) {
        $sql .= " WHERE $constraint";
    }

    my $sth = $self->prepare($sql);
    $sth->execute();
    my $id;
    $sth->bind_columns(\$id);

    my $more_items = 1;
    $cache_size ||= 1000; ## Default: 1000 members per chunk
    my @cache;

    my $closure = sub {
        if (@cache == 0 && $more_items) {
            my @dbIDs;
            my $items_counter = 0;
            while ($sth->fetch) {
                push @dbIDs, $id;
                if (++$items_counter == $cache_size) {
                    $more_items = 1;
                    last;
                }
                $more_items = 0;
            }
            $sth->finish() unless ($more_items);
            @cache = @{ $self->fetch_all_by_dbID_list(\@dbIDs) } if scalar(@dbIDs);
        }
        return shift @cache;
    };

    return Bio::EnsEMBL::Utils::Iterator->new($closure);
}


1;

