=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Compara::Utils::Scalar qw(:argument);

use base ('Bio::EnsEMBL::DBSQL::BaseAdaptor');

use constant ID_CHUNK_SIZE => 500;


=head2 attach

  Example     : $self->attach($object, $dbID);
  Description : Simple method that attaches the object to this adaptor, and sets the dbID at the same time.
  Returntype  : Integer. The new dbID of the object
  Exceptions  : none
  Caller      : Adaptors (usually whilst fetching objects)
  Status      : Stable

=cut

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
                'm.seq_member_id = fm.seq_member_id',
                # the join condition (mandatory)
                [qw(fm.family_id fm.seq_member_id fm.cigar_line)]]
                # any additional columns that the join could imply (optional)
                # as an arrayref 
  Arg [3]    : (optional) string $final_clause
               Additional clause to the end of the SQL query used to fetch feature
               records. This is useful to add a required ORDER BY or LIMIT clause
               to the query for example. This argument overrides the return value
               of $self->_final_clause()
  Arg [4]    : (optional) string $column_clause
               List of columns (or expressions) to retrieve. Overrides the default
               built from L<_columns()> and $join. $column_clause must be a valid,
               complete, clause such as "root_id AS rr, node_id AS nn"
  Example    : $sql = $a->construct_sql_query($constraint, $join);
  Description: Builds a personalized SQL query that can be used to fetch the data.
  Returntype : String
  Exceptions : none
  Caller     : almost only generic_fetch()

=cut
  
sub construct_sql_query {
    my ($self, $constraint, $join, $final_clause, $column_clause) = @_;

    my @tabs = $self->_tables;
    my $columns = join(', ', $self->_columns());
    my @all_extra_columns;
    $self->{_all_extra_columns} = \@all_extra_columns;

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
            if ($extra_columns && (ref($extra_columns) eq 'ARRAY')) {
                $columns .= ", " . join(', ', @{$extra_columns});

            } elsif ($extra_columns && (ref($extra_columns) eq 'HASH')) {
                my @sorted_keys = sort keys %$extra_columns;
                push @all_extra_columns, @$extra_columns{@sorted_keys};
                $columns .= ", " . join(', ', @sorted_keys);
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

    # Overrides the default
    $columns = $column_clause if $column_clause;

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


=head2 generic_count

  Arguments  : Same arguments as construct_sql_query()
  Example    : $n_rows = $a->generic_count($constraint, $join, $final_clause);
  Description: Performs a database query to count the number of elements
  Returntype : integer
  Exceptions : none
  Caller     : various adaptors' specific couont_ subroutines

=cut

sub generic_count {
    my ($self, $constraint, $join, $final_clause) = @_;
    my $sql = $self->construct_sql_query($constraint, $join, $final_clause, 'COUNT(*)');
    my $sth = $self->_bind_params_and_execute($sql);
    my ($count) = $sth->fetchrow_array();  # Assumes no GROUP BY
    $sth->finish;
    return $count;
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
    my ($self, $constraint, $join, $final_clause) = @_;
    my $sql = $self->construct_sql_query($constraint, $join, $final_clause);
    my $sth = $self->_bind_params_and_execute($sql);
    my $obj_list = $self->_objs_from_sth($sth);
    $sth->finish;
    return $obj_list;
}


=head2 _bind_params_and_execute

  Arg[1]     : String $sql. The SQL statement to execute
  Description: Prepare the statement, bind the parameters from bind_param_generic_fetch() and execute the statement
  Returntype : Execute statement-handle
  Exceptions : none
  Caller     : generic_fetch() and generic_count()

=cut

sub _bind_params_and_execute {
    my ($self, $sql) = @_;
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
    return $sth;
}


=head2 generic_objs_from_sth

  Arg [1]     : $sth Statement handle
  Arg [2]     : String $class. The package name of the new objects to build
  Arg [3]     : Arrayref of strings $field_names. How each column is named in the
                object hash (use undef to skip a column)
  Arg [4]     : (opt) $callback. Callback method to provide additional fields
  Example     : my $generic_objs_from_sth = $object_name->generic_objs_from_sth();
  Description : Generic method that can fulfill the role of _objs_from_sth().
                It will iterate over each row of the resultset, call new_fast() to
                build a new object and map each column to an internal field.
                $callback can be used to provide additional fields or to transform
                some (first set them to undef in $field_names)
  Returntype  : Arrayref of objects
  Exceptions  : none
  Caller      : Adaptors (usually in _objs_from_sth() of fetch*)
  Status      : Stable

=cut

sub generic_objs_from_sth {
    my ($self, $sth, $class, $field_names, $callback) = @_;

    push @$field_names, @{$self->{_all_extra_columns}};   # Requested by on-the-fly JOINs
    my @vals = map {undef} @$field_names;
    my @ind  = 0..(scalar(@vals)-1);

    my @objs;
    $sth->bind_columns(\(@vals));
    while ( $sth->fetch() ) {
        my $obj = $class->new_fast( {
                'adaptor' => $self,
                (map {$field_names->[$_] => $vals[$_]} grep {$field_names->[$_]} @ind),
                $callback ? (%{ $callback->(\@vals) }) : (),
            } );
        push @objs, $obj;
    }
    return \@objs;
}


=head2 mysql_server_prepare

  Arg[1]      : Boolean (opt)
  Example     : $self->compara_dba->get_HomologyAdaptor->mysql_server_prepare();
  Description : Getter / setter. Controls whether statements are prepared server-side,
                which should give better performance for repeated queries.
                DO NOT enable by default, there is still a memory leak:
                 L<https://rt.cpan.org/Public/Bug/Display.html?id=83486>
  Returntype  : Boolean
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub mysql_server_prepare {
    my $self = shift;
    # Internally there is no '_mysql_server_prepare' field but
    # only '_cached_statements'. The existence of the latter tells whether
    # the option is turned on. The setter must thus ensure the hash is
    # deleted when the option is switched off
    return (exists $self->{'_cached_statements'} ? 1 : 0) unless scalar(@_);
    my $value = shift;
    if ($value) {
        $self->{'_cached_statements'} = {} unless exists $self->{'_cached_statements'};
        return 1;
    } else {
        return 0 unless exists $self->{'_cached_statements'};
        foreach my $sth (values %{$self->{'_cached_statements'}}) {
            $sth->finish;
        }
        delete $self->{'_cached_statements'};
        return 0;
    }
}


=head2 prepare

  Arg [1]    : string $string
               a SQL query to be prepared by this adaptors database
  Example    : $sth = $adaptor->prepare("select yadda from blabla")
  Description: provides a DBI statement handle from the adaptor. A convenience
               function so you dont have to write $adaptor->db->prepare all the
               time. It will perform a server-side preparation if the mysql_server_prepare()
               flag has been switched on
  Returntype : DBI::StatementHandle
  Exceptions : none
  Caller     : Adaptors inherited from BaseAdaptor
  Status     : Stable

=cut

sub prepare {
    my ($self, $query, @args) = @_;

    #$query =~ s/SELECT/SELECT SQL_NO_CACHE/i;

    if (exists $self->{'_cached_statements'}) {
        return $self->{'_cached_statements'}->{$query} if exists $self->{'_cached_statements'}->{$query};
        $self->dbc->db_handle->{mysql_server_prepare} = 1;
        my $sth = $self->SUPER::prepare($query, @args);
        $self->dbc->db_handle->{mysql_server_prepare} = 0;
        $self->{'_cached_statements'}->{$query} = $sth if $sth;
        return $sth;
    } else {
        return $self->SUPER::prepare($query, @args);
    }
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

  Arguments  : Same arguments as construct_sql_query()
  Example    : $obj = $a->generic_fetch_Iterator('taxon_id = 9606');
  Description: Performs a database fetch and returns an iterator over it
  Returntype : Bio::EnsEMBL::Utils::Iterator
  Exceptions : none
  Caller     : various adaptors' specific fetch_ subroutines

=cut

sub generic_fetch_Iterator {
    my ($self, $constraint, $join, $final_clause) = @_;

    my ($name, $syn) = @{($self->_tables)[0]};
    my $sql = $self->construct_sql_query($constraint, $join, $final_clause, $name.'_id');

    # Fetch all the dbIDs
    my $sth = $self->prepare($sql);
    $sth->execute();
    my $id;
    $sth->bind_columns(\$id);

    my $more_items = 1;
    my @cache;

    my $closure = sub {
        if (@cache == 0 && $more_items) {
            my @dbIDs;
            my $items_counter = 0;
            while ($sth->fetch) {
                push @dbIDs, $id;
                if (++$items_counter == ID_CHUNK_SIZE) {
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


=head2 split_and_callback

  Arg[1]      : Arrayref $list_of_values. All the IDs to retrieve
  Arg[2]      : String $column_name - Name of the column in the table the IDs can be found in
  Arg[3]      : Integer $column_sql_type. DBI's "SQL type"
  Arg[4]      : Callback function $callback
  Example     : $adaptor->split_and_callback($stable_ids, 'm.stable_id', SQL_VARCHAR, sub { ... });
  Description : Wrapper around the given callback that calls it iteratively with IN constraints
                that contain chunks of $list_of_values.
  Returntype  : none
  Exceptions  : none
  Caller      : general

=cut

sub split_and_callback {
    my ($self, $list_of_values, $column_name, $column_sql_type, $callback) = @_;
    foreach my $id_list (@{ split_list($list_of_values, ID_CHUNK_SIZE) }) {
        $callback->($self->generate_in_constraint($id_list, $column_name, $column_sql_type, 1)) ;
    }
}


=head2 generic_fetch_concatenate

  Arg[1]      : Arrayref $list_of_values. All the IDs to retrieve
  Arg[2]      : String $column_name - Name of the column in the table the IDs can be found in
  Arg[3]      : Integer $column_sql_type. DBI's "SQL type"
  Arg[4,5]    : Extra parameters passed to generic_fetch() (after the where constraint)
  Example     : $adaptor->generic_fetch_concatenate($stable_ids, 'm.stable_id', SQL_VARCHAR);
  Description : Special version of split_and_callback() that calls generic_fetch() with the
                The core API already has already such a method - _uncached_fetch_all_by_id_list() -
                so this one is only needed if you want to use join clauses or a "final" clause.
  Returntype  : Arrayref of objects
  Exceptions  : none
  Caller      : general

=cut

sub generic_fetch_concatenate {
    my ($self, $list_of_values, $column_name, $column_sql_type, @generic_fetch_args) = @_;
    my @results;
    $self->split_and_callback($list_of_values, $column_name, $column_sql_type, sub {
        push @results, @{ $self->generic_fetch(shift, @generic_fetch_args) };
    } );
    return \@results;
}


# The Core API selects too large chunks. Here we reduce $max_size
sub _uncached_fetch_all_by_id_list {
    my ($self, $id_list_ref, $slice, $id_type, $numeric) = @_;
    return $self->SUPER::_uncached_fetch_all_by_id_list($id_list_ref, $slice, $id_type, $numeric, ID_CHUNK_SIZE);
}


=head2 _synchronise

  Arg [1]     : $obj. The object to check in the database
  Example     : my $exist_obj = $self->_synchronise($test_obj);
  Description : Check in the database whether there is already an object with the
                same properties. The test is performed against the columns defined
                in _unique_attributes() and the dbID column. The function will die
                if there is already an object with either of these conditions:
                 - same dbID (when $obj has a dbID) but different data
                 - same data but different dbID (when $obj has a dbID)
  Returntype  : Object instance or undef
  Exceptions  : Dies if there is a collision
  Caller      : Adaptors only
  Status      : Stable

=cut

sub _synchronise {
    my ($self, $object) = @_;

    assert_ref($object, $self->object_class, 'argument to _synchronise');

    my $dbID            = $object->dbID();
    my $dbID_field      = ($self->_columns())[0];

    my @unique_data_check = ();
    my @unique_key_check  = ();

    foreach my $attr ($self->_unique_attributes) {
        if (defined $object->$attr) {
            push @unique_data_check, $object->$attr;
            push @unique_key_check,  "$attr = ?";
        } else {
            push @unique_key_check,  "$attr IS NULL";
        }
    }

    my ($table) = $self->_tables();
    my $x = join(' AND ', @unique_key_check);
    my $y = join(' ', @$table);
    my $sth = $self->prepare( "SELECT $dbID_field, ($x) AS existing_unique_data FROM $y WHERE $dbID_field = ? OR ($x)");
    $sth->execute(@unique_data_check, $dbID, @unique_data_check);

    my $vectors = $sth->fetchall_arrayref();
    $sth->finish();

    if( scalar(@$vectors) >= 2 ) {
        die "Attempting to store an object with dbID=$dbID experienced partial collisions on both dbID and data in the db\n";
    } elsif( scalar(@$vectors) == 1 ) {
        my ($stored_dbID, $unique_key_check) = @{$vectors->[0]};

        if(!$unique_key_check) {
            die "Attempting to store an object with dbID=$dbID experienced a collision with same dbID but different data\n";
        } elsif($dbID and ($dbID!=$stored_dbID)) {
            die "Attempting to store an object with dbID=$dbID experienced a collision with same data but different dbID ($stored_dbID)\n";
        } else {
            $self->attach( $object, $stored_dbID);
            return $self->fetch_by_dbID($stored_dbID);
        }
    } else {
        return undef;   # not found, safe to insert
    }
}


=head2 _unique_attributes

  Description : Returns a list of attributes that can uniquely identify an object
                for this adaptor.
  Returntype  : List of attribute names
  Exceptions  : none
  Caller      : _synchronise()
  Status      : Stable

=cut

sub _unique_attributes {
    return ();
}


=head2 generic_insert

  Arg [1]     : String $table. Tha name of the table
  Arg [2]     : Hashref $col_to_values. Mapping between the column names and the values to insert
  Arg [3]     : (opt) String $last_insert_id_column. Name of the column to retrieve an AUTO_INCREMENT from
  Example     : my $dbID = $self->generic_insert('method_link', {
                        'method_link_id'    => $method->dbID,
                        'type'              => $method->type,
                        'class'             => $method->class,
                    }, 'method_link_id');
                $self->attach($method, $dbID);
  Description : Generic method to insert a row into a table. It automatically writes an
                INSERT statement with the correct list of columns, number of placeholders;
                then executes it and queries the value of $last_insert_id_column.
  Returntype  : Integer. Value of the $last_insert_id_column (if requested)
                This may be a copy of what has been provided in $col_to_values;
  Exceptions  : none
  Caller      : Adaptors (usually store())
  Status      : Stable

=cut

sub generic_insert {
    my ($self, $table, $col_to_values, $last_insert_id_column) = @_;

    my $dbID;

    if ($last_insert_id_column) {
        if (defined ($dbID = $col_to_values->{$last_insert_id_column})) {
            # dbID provided, so nothing to return
            $last_insert_id_column = undef;
        } else {
            # dbID not provided, let's skip the column to make clear we want an AUTO_INCREMENT
            delete $col_to_values->{$last_insert_id_column};
        }
    }

    my @columns = keys %$col_to_values;
    my @values = map {$col_to_values->{$_}} @columns;
    my $sql = sprintf('INSERT INTO %s (%s) VALUES (%s)', $table, join(', ', @columns), join(', ', map {'?'} @columns));
    my $sth = $self->prepare( $sql ) or die "Could not prepare '$sql'\n";
    $sth->execute(map {$col_to_values->{$_}} @columns)
        or die sprintf("Could not store (%s)\n", join(', ', map {$_.'='.($col_to_values->{$_} // '<NULL>')} @columns));

    # This assumes that the first field is the auto_increment column
    if ($last_insert_id_column) {
        $dbID = $self->dbc->db_handle->last_insert_id(undef, undef, $table, $last_insert_id_column)
                    or die "Failed to obtain a dbID from the $table table\n";
    }
    $sth->finish();
    return $dbID;
}


=head2 generic_multiple_insert

  Arg [1]     : String $table. Tha name of the table
  Arg [2]     : Arrayref $columns. Name of the columns to populate
  Arg [3]     : Arrayref of the values (row by row) and ordered as in $columns
  Example     : $self->generic_multiple_insert(
                    'species_set',
                    ['species_set_id', 'genome_db_id'],
                    [map {[$dbID, $_->dbID]} @$genome_dbs]
                );
  Description : Generic method to insert many rows into a table. It automatically writes an
                INSERT statement with the correct list of columns, number of placeholders;
                then executes it at once with execute_array().
                NOTE: The function empties $input_data, so provide a copy if you need the data
                In theory, execute_array() is supposed to be able to call INSERT with multiple
                rows at once, making it similarly efficient as SQL statements from mysqldump,
                but I haven't seen that in my benchmark. Not sure DBD::mysql supports that.
                If you require performance, have a look at Utils::CopyData
  Returntype  : none
  Exceptions  : none
  Caller      : Adaptors (usually store())
  Status      : Stable

=cut

sub generic_multiple_insert {
    my ($self, $table, $columns, $input_data) = @_;

    my $sql = sprintf('INSERT INTO %s (%s) VALUES (%s)', $table, join(', ', @$columns), join(', ', map {'?'} @$columns));
    my $sth = $self->prepare( $sql ) or die "Could not prepare '$sql'\n";
    my $fetch_callback = (ref($input_data) eq 'ARRAY') ? sub {shift @$input_data} : $input_data;
    $sth->execute_for_fetch( $fetch_callback )
        or die sprintf("Could not store values as (%s)\n", join(', ', @$columns));
    $sth->finish();
}


=head2 generic_update

  Arg [1]     : String $table. Tha name of the table
  Arg [2]     : Hashref $col_to_values_update. Mapping between the column names and the values to update
  Arg [3]     : Hashref $col_to_values_where. Mapping between the column names and the values for the WHERE clause
  Example     : $self->generic_update('method_link',
                    {
                        'type'              => $method->type,
                        'class'             => $method->class,
                    }, {
                        'method_link_id'    => $method->dbID,
                    } );
  Description : Generic method to update a row in a table. It automatically writes an UPDATE
                statement with the correct list of columns and number of placeholders on both
                the SET and WHERE clauses; then executes it.
  Returntype  : Number of rows affected (as return by execute())
  Exceptions  : none
  Caller      : Adaptors (usually store())
  Status      : Stable

=cut

sub generic_update {
    my ($self, $table, $col_to_values_update, $col_to_values_where) = @_;

    my @columns_update = keys %$col_to_values_update;
    my @columns_where = keys %$col_to_values_where;
    my $sql = sprintf('UPDATE %s SET %s WHERE %s', $table, join(', ', map {$_.'=?'} @columns_update), join(' AND ', map {$_.'=?'} @columns_where));
    my $sth = $self->prepare( $sql ) or die "Could not prepare '$sql'\n";
    my $rc = $sth->execute((map {$col_to_values_update->{$_}} @columns_update), (map {$col_to_values_where->{$_}} @columns_where));
    $sth->finish;
    return $rc;
}


=head2 delete_by_dbID

  Arg [1]     : int $id. The unique database identifier for the feature to be deleted
  Example     : $adaptor->delete_by_dbID(123);
  Description : Generic method to delete an entry from the database. Note that this
                basic implementation is not aware of table relations and foreign keys
                and may either fail or leave the database in an inconsistent state.
  Returntype  : none
  Exceptions  : none
  Caller      : general

=cut

sub delete_by_dbID {
    my ($self, $id) = @_;

    throw("id argument is required") if(!defined $id);

    my ($name, $syn) = @{($self->_tables)[0]};
    my $delete_sql = qq{DELETE FROM $name WHERE ${name}_id = ?};

    $self->dbc->do($delete_sql, undef, $id);
}


1;

