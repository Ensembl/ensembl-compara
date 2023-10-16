=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::Utils::CopyData

=head1 DESCRIPTION

This package exports method to copy data between databases.

=head2 :table_copy export-tag

copy_table() is used to copy whole tables or large chunks of data,
without paying attention to the foreign-key constraints. If defined,
the filter can only be a straight WHERE clause.

For more advanced cases, copy_data() can run an arbitrary query and
insert its result into another table. Use copy_data() when you need to
join to another table.

copy_data() automatically chooses the optimal
transfer mode depending on the type of query and the data types.

=head2 :row_copy export-tag

copy_data_with_foreign_keys_by_constraint() can copy individual rows with
their own depedencies. It will also "expand" the data, for instance by
copying homology_member too when asked to copy homology.

=head2 :insert export-tag

single_insert(), bulk_insert() and bulk_insert_iterator() are simple
methods to run INSERT statements.  bulk_insert() and bulk_insert_iterator()
are optimized to insert large chunks of data.

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::Utils::CopyData (:row_copy);
  # The ", 1" at the end tells the function to "expand" the data, i.e. copy
  # extra rows to make the objects complete. Without it, it wouldn't copy
  # family_member
  copy_data_with_foreign_keys_by_constraint($source_dbc, $target_dbc, 'family', 'stable_id', 'ENSFM00730001521062', undef, 1);
  copy_data_with_foreign_keys_by_constraint($source_dbc, $target_dbc, 'gene_tree_root', 'stable_id', 'ENSGT00390000003602', undef, 1);

  # To insert a large number of rows in an optimal manner
  bulk_insert($self->compara_dba->dbc, 'homology_id_mapping', $self->param('homology_mapping'), ['mlss_id', 'prev_release_homology_id', 'curr_release_homology_id'], 'INSERT IGNORE');

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=cut

package Bio::EnsEMBL::Compara::Utils::CopyData;

use strict;
use warnings;

use base qw(Exporter);

our %EXPORT_TAGS;
our @EXPORT_OK;

@EXPORT_OK = qw(
    copy_data_with_foreign_keys_by_constraint
    clear_copy_data_cache
    copy_data
    copy_data_pp
    copy_table
    bulk_insert
    bulk_insert_iterator
    single_insert
);
%EXPORT_TAGS = (
  'row_copy'    => [qw(copy_data_with_foreign_keys_by_constraint clear_copy_data_cache)],
  'table_copy'  => [qw(copy_data copy_data_pp copy_table)],
  'insert'      => [qw(bulk_insert bulk_insert_iterator single_insert)],
  'all'         => [@EXPORT_OK]
);

use constant MAX_STATEMENT_LENGTH => 1_000_000;             # Related to MySQL's "max_allowed_packet" parameter

use Bio::EnsEMBL::Utils::Iterator;
use Bio::EnsEMBL::Utils::Scalar qw(check_ref assert_ref);
use Bio::EnsEMBL::Compara::Utils::RunCommand;

my %foreign_key_cache = ();

my %data_expansions = (
    'ncbi_taxa_node' => [['taxon_id', 'ncbi_taxa_name', 'taxon_id'], ['parent_id', 'ncbi_taxa_node', 'taxon_id']],
    'gene_tree_root' => [['root_id', 'gene_tree_root_tag', 'root_id'], ['root_id', 'gene_tree_root_attr', 'root_id'], ['root_id', 'gene_tree_root', 'ref_root_id'], ['root_id', 'gene_tree_node', 'root_id'], ['root_id', 'homology', 'gene_tree_root_id'], ['root_id', 'CAFE_gene_family', 'gene_tree_root_id']],
    'CAFE_gene_family' => [['cafe_gene_family_id', 'CAFE_species_gene', 'cafe_gene_family_id']],
    'gene_tree_node' => [['node_id', 'gene_tree_node_tag', 'node_id'], ['node_id', 'gene_tree_node_attr', 'node_id']],
    'species_tree_node' => [['node_id', 'species_tree_node_tag', 'node_id'],['node_id', 'species_tree_node_attr', 'node_id'], ['root_id', 'species_tree_root', 'root_id'], ['parent_id', 'species_tree_node', 'node_id']],
    'species_tree_root' => [['root_id', 'species_tree_node', 'root_id']],
    'method_link_species_set' => [['method_link_species_set_id', 'method_link_species_set_tag', 'method_link_species_set_id'], ['method_link_species_set_id', 'method_link_species_set_attr', 'method_link_species_set_id']],
    'species_set_header' => [['species_set_id', 'species_set', 'species_set_id'], ['species_set_id', 'species_set_tag', 'species_set_id']],
    'family' => [['family_id', 'family_member', 'family_id']],
    'homology' => [['homology_id', 'homology_member', 'homology_id']],
    'gene_align' => [['gene_align_id', 'gene_align_member', 'gene_align_id']],
    'seq_member' => [['seq_member_id', 'other_member_sequence', 'seq_member_id'], ['seq_member_id', 'exon_boundaries', 'seq_member_id']],
    'gene_member' => [['canonical_member_id', 'seq_member', 'seq_member_id']],
    'synteny_region' => [['synteny_region_id', 'dnafrag_region', 'synteny_region_id']],
    'genomic_align_block' => [['genomic_align_block_id', 'genomic_align', 'genomic_align_block_id'], ['genomic_align_block_id', 'conservation_score', 'genomic_align_block_id']],
    # FIXME: how to expand genomic_align_tree ?

);


=head2 copy_data_with_foreign_keys_by_constraint

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $from_dbc
  Arg[2]      : Bio::EnsEMBL::DBSQL::DBConnection $to_dbc
  Arg[3]      : string $table_name
  Arg[4]      : (opt) string $where_field: the name of the column to use for the filtering
  Arg[5]      : (opt) string $where_value: the value of the column used for the filtering
  Arg[6]      : (opt) Bio::EnsEMBL::DBSQL::DBConnection $foreign_keys_dbc
  Arg[7]      : (bool) $expand_tables (default 0)

  Description : Copy the rows of this table that match the condition. Dependant rows
                (because of foreign keys) are automatically copied over. Foreign keys
                are discovered by asking the DBI layer. This is obviously only available
                for InnoDB, so if the schema is in MyISAM you'll have to provide
                $foreign_keys_dbc.
                If $expand_tables is set, the function will copy extra rows to make the
                objects "complete" (e.g. copy homology_member too if asked to copy homology)

=cut

sub copy_data_with_foreign_keys_by_constraint {
    my ($from_dbc, $to_dbc, $table_name, $where_field, $where_value, $foreign_keys_dbc, $expand_tables) = @_;
    assert_ref($from_dbc, 'Bio::EnsEMBL::DBSQL::DBConnection', 'from_dbc');
    assert_ref($to_dbc, 'Bio::EnsEMBL::DBSQL::DBConnection', 'to_dbc');
    die "A table name must be given" unless $table_name;
    my $fk_rules = _load_foreign_keys($foreign_keys_dbc, $to_dbc, $from_dbc);
    _memoized_insert($from_dbc, $to_dbc, $table_name, $where_field, $where_value, $fk_rules, $expand_tables);
}

# Load all the foreign keys and cache the result
sub _load_foreign_keys {

    foreach my $dbc (@_) {
        next unless check_ref($dbc, 'Bio::EnsEMBL::DBSQL::DBConnection');
        return $foreign_key_cache{$dbc->locator} if $foreign_key_cache{$dbc->locator};

        my $sth = $dbc->db_handle->foreign_key_info(undef, $dbc->dbname, undef, undef, undef, undef);
        my %fk = ();
        foreach my $x (@{ $sth->fetchall_arrayref() }) {
            # A.x REFERENCES B.y : push @{$fk{'A'}}, ['x', 'B', 'y'];
            push @{$fk{$x->[6]}}, [$x->[7], $x->[2], $x->[3]];
        }
        if (%fk) {
            $foreign_key_cache{$dbc->locator} = \%fk;
            return $foreign_key_cache{$dbc->locator};
        }
    }
    die "None of the DBConnections point to a database with foreign keys. Foreign keys are needed to populate linked tables\n";
}


my %cached_inserts = ();
sub _memoized_insert {
    my ($from_dbc, $to_dbc, $table, $where_field, $where_value, $fk_rules, $expand_tables) = @_;

    my $key = $table;
    $key .= "||$where_field=" . ($where_value // '__NA__') if $where_field;
    return if $cached_inserts{$from_dbc->locator}{$to_dbc->locator}{$key};
    $cached_inserts{$from_dbc->locator}{$to_dbc->locator}{$key} = 1;

    my $sql_select;
    my @execute_args;
    if ($where_field) {
        if (defined $where_value) {
            $sql_select = sprintf('SELECT * FROM %s WHERE %s = ?', $table, $where_field);
            push @execute_args, $where_value;
        } else {
            $sql_select = sprintf('SELECT * FROM %s WHERE %s IS NULL', $table, $where_field);
        }
    } else {
        $sql_select = 'SELECT * FROM '.$table;
    }
    #warn "<< $sql_select  using '@execute_args'\n";
    my $sth = $from_dbc->prepare($sql_select);
    $sth->execute(@execute_args);
    while (my $h = $sth->fetchrow_hashref()) {
        my %this_row = %$h;

        # First insert the requirements (to satisfy the foreign keys)
        _insert_related_rows($from_dbc, $to_dbc, \%this_row, $fk_rules->{$table}, $table, $where_field, $where_value, $fk_rules, $expand_tables);

        # Then the data
        my @cols = keys %this_row;
        my @qms  = map {'?'} @cols;
        my @vals = @this_row{@cols};
        my $insert_sql = sprintf('INSERT IGNORE INTO %s (%s) VALUES (%s)', $table, join(',', map{"`$_`"}@cols), join(',', @qms));
        #warn ">> $insert_sql using '", join("','", map {$_//'<NULL>'} @vals), "'\n";
        my $rows = $to_dbc->do($insert_sql, undef, @vals);
        #warn "".($rows ? "true" : "false")." ".($rows == 0 ? "zero" : "non-zero")."\n";
        # no rows affected is translated into '0E0' which is true and ==0 at the same time
        if ($rows) {
            if ($rows == 0) {
                # The row was already there, but we can't assume it's been expanded too
            }
        } else {
            die "FAILED: ".$to_dbc->db_handle->errstr;
        }

        # And the expanded stuff
        _insert_related_rows($from_dbc, $to_dbc, \%this_row, $data_expansions{$table}, $table, $where_field, $where_value, $fk_rules, $expand_tables) if $expand_tables;
    }
}

sub _insert_related_rows {
    my ($from_dbc, $to_dbc, $this_row, $rules, $table, $where_field, $where_value, $fk_rules, $expand_tables) = @_;
    foreach my $x (@$rules) {
        #warn sprintf("%s(%s) needs %s(%s)\n", $table, @$x);
        if (not defined $this_row->{$x->[0]}) {
            next;
        } elsif (($table eq $x->[1]) and $where_field and ($where_field eq $x->[2]) and (defined $where_value) and ($where_value eq $this_row->{$x->[0]})) {
            # self-loop catcher: the code is about to store the same row again and again
            # we fall here when trying to insert a root gene_tree_node because its root_id links to itself
            next;
        }
        _memoized_insert($from_dbc, $to_dbc, $x->[1], $x->[2], $this_row->{$x->[0]}, $fk_rules, $expand_tables);
    }
}


=head2 clear_copy_data_cache

  Description : Clears the cache to free up some memory

=cut

sub clear_copy_data_cache {
    %cached_inserts = ();
}


=head2 copy_data

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $from_dbc
  Arg[2]      : Bio::EnsEMBL::DBSQL::DBConnection $to_dbc
  Arg[3]      : string $table_name
  Arg[4]      : string $query
  Arg[5]      : (opt) boolean $replace (default: false)
  Arg[6]      : (opt) boolean $skip_disable_vars (default: false)
  Arg[7]      : (opt) boolean $debug (default: false)

  Description : Copy the output of the query to this table

=cut

sub copy_data {
    my ($from_dbc, $to_dbc, $table_name, $query, $replace, $skip_disable_vars, $debug) = @_;

    assert_ref($from_dbc, 'Bio::EnsEMBL::DBSQL::DBConnection', 'from_dbc');
    assert_ref($to_dbc, 'Bio::EnsEMBL::DBSQL::DBConnection', 'to_dbc');

    unless (defined $table_name && defined $query) {
        die "table_name and query are mandatory parameters";
    };
    my $load_query = "LOAD DATA LOCAL INFILE '/dev/stdin' " . ($replace ? 'REPLACE' : 'IGNORE' ) . " INTO TABLE $table_name";

    # escape quotes to avoid nesting
    $query =~ s/\\?"/\\"/g;

    print "Copying data in table $table_name\n" if $debug;

    my $from_user = $from_dbc->username;
    my $from_pass = $from_dbc->password;
    my $from_host = $from_dbc->host;
    my $from_port = $from_dbc->port;
    my $from_dbname = $from_dbc->dbname;

    my $to_user = $to_dbc->username;
    my $to_pass = $to_dbc->password;
    my $to_host = $to_dbc->host;
    my $to_port = $to_dbc->port;
    my $to_dbname = $to_dbc->dbname;

    # Check the column information: if there is at least one binary column, alter the given query and the
    # LOAD DATA query to handle the binary columns accordingly
    my $sth = $from_dbc->db_handle->column_info($from_dbname, undef, $table_name, '%');
    my $columns_info = $sth->fetchall_arrayref;
    my $binary_mode = 0;
    my (@select_cols, @load_cols, @set_exprs);
    foreach my $col ( @$columns_info ) {
        if ($col->[5] =~ /(^BIT|BLOB|BINARY)$/) {
            $binary_mode = 1;
            push @select_cols, "HEX($table_name." . $col->[3] . ")";
            push @load_cols, "@" . $col->[3];
            push @set_exprs, $col->[3] . " = UNHEX(@" . $col->[3] . ")";
        } else {
            push @select_cols, "$table_name." . $col->[3];
            push @load_cols, $col->[3];
        }
    }
    if ($binary_mode) {
        # Replace the wildcard by the list of columns (including the HEX-ing of the binary ones)
        my $select_cols = join(', ', @select_cols);
        $query =~ s/($table_name\.|)\*/$select_cols/;
        # Make LOAD DATA aware of which columns to UNHEX
        $load_query .= sprintf(" (%s) SET %s", join(', ', @load_cols), join(', ', @set_exprs));
    }

    # Get table's engine to optimise the copy process
    my $table_engine;
    unless ($skip_disable_vars) {
        $table_engine = $to_dbc->db_handle->selectrow_hashref("SHOW TABLE STATUS WHERE Name = '$table_name'")->{Engine};
        # Speed up writing of data by disabling certain variables, write the data, then enable them back
        print "DISABLE VARIABLES\n" if $debug;
        if ($table_engine eq 'MyISAM') {
            $to_dbc->do("ALTER TABLE `$table_name` DISABLE KEYS");
        } else {
            $load_query = "SET AUTOCOMMIT = 0; SET FOREIGN_KEY_CHECKS = 0; " .
                $load_query ."; SET AUTOCOMMIT = 1; SET FOREIGN_KEY_CHECKS = 1;";
        }
    }

    # Disconnect from the databases before copying the table
    $from_dbc->disconnect_if_idle();
    $to_dbc->disconnect_if_idle();

    my $start_time  = time();
    my $cmd = "mysql --host=$from_host --port=$from_port --user=$from_user " . ($from_pass ? "--password=$from_pass " : '') .
        "--max_allowed_packet=1024M $from_dbname -e \"$query\" --quick --silent --skip-column-names " .
        "| LC_ALL=C sed -r -e 's/\\r//g' -e 's/(^|\\t)NULL(\$|\\t)/\\1\\\\N\\2/g' -e 's/(^|\\t)NULL(\$|\\t)/\\1\\\\N\\2/g' " .
        "| mysql --host=$to_host --port=$to_port --user=$to_user " . ($to_pass ? "--password=$to_pass " : '') . '--local-infile=1 ' .
        "$to_dbname -e \"$load_query\"";
    Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd, { die_on_failure => 1, use_bash_pipefail => 1, debug => $debug });
    print "total time: " . (time - $start_time) . " s\n" if $debug;

    unless ($skip_disable_vars) {
        print "ENABLE VARIABLES\n" if $debug;
        $to_dbc->do("ALTER TABLE `$table_name` ENABLE KEYS") if ($table_engine eq 'MyISAM');
    }
}


=head2 copy_table

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $from_dbc
  Arg[2]      : Bio::EnsEMBL::DBSQL::DBConnection $to_dbc
  Arg[3]      : string $table_name
  Arg[4]      : (opt) string $where_filter
  Arg[5]      : (opt) boolean $replace (default: false)
  Arg[6]      : (opt) boolean $skip_disable_vars (default: false)
  Arg[7]      : (opt) boolean $debug (default: false)

  Description : Copy the table (either all of it or a subset).
                The main optional argument is $where_filter, which allows to select a portion of
                the table. Note: the filter must be valid on the table alone, and does not support
                JOINs. If you need the latter, use copy_data()

=cut

sub copy_table {
    my ($from_dbc, $to_dbc, $table_name, $where_filter, $replace, $skip_disable_vars, $debug) = @_;

    my $query = "SELECT * FROM $table_name" . ($where_filter ? " WHERE $where_filter" : '');
    copy_data($from_dbc, $to_dbc, $table_name, $query, $replace, $skip_disable_vars, $debug);
}


=head2 copy_data_pp

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $from_dbc
  Arg[2]      : Bio::EnsEMBL::DBSQL::DBConnection $to_dbc
  Arg[3]      : string $table_name
  Arg[4]      : string $query
  Arg[5]      : (opt) boolean $replace (default: false)
  Arg[6]      : (opt) boolean $ignore_foreign_keys (default: false)
  Arg[7]      : (opt) boolean $debug (default: false)

  Description : "Pure-Perl" implementation of copy_data(). It loads the rows from
                the query and builds multi-inserts statements. As everything remains
                within the Perl DBI layers, this method is suitable when a transaction
                on the target database is required.
                Rows are inserted with INSERT IGNORE, or REPLACE if $replace is set.
  Return      : Integer - The number of rows copied over

=cut

sub copy_data_pp {
    my ($from_dbc, $to_dbc, $table_name, $query, $replace, $ignore_fks, $debug) = @_;

    assert_ref($from_dbc, 'Bio::EnsEMBL::DBSQL::DBConnection', 'from_dbc');
    assert_ref($to_dbc, 'Bio::EnsEMBL::DBSQL::DBConnection', 'to_dbc');

    unless (defined $table_name && defined $query) {
        die "table_name and query are mandatory parameters";
    };

    print "Copying data in table $table_name\n" if $debug;

    my $sth = $from_dbc->prepare($query, { 'mysql_use_result' => 1 });
    $sth->execute();
    my $fetch_sub = sub {
        return $sth->fetchrow_arrayref;
    };
    my $insertion_mode = $replace ? 'REPLACE' : 'INSERT IGNORE';
    my $total_rows = bulk_insert_iterator($to_dbc, $table_name, Bio::EnsEMBL::Utils::Iterator->new($fetch_sub), undef, $insertion_mode, $ignore_fks, $debug);
    $sth->finish;
    return $total_rows;
}


=head2 single_insert

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $dest_dbc
  Arg[2]      : string $table_name
  Arg[3]      : arrayref of values$data
  Arg[4]      : (opt) arrayref of strings $col_names (defaults to the column-order at the database level)
  Arg[5]      : (opt) string $insertion_mode (default: 'INSERT')

  Description : Simple method to execute an INSERT statement without having to write it. The values
                in $data must be in the same order as in $col_names (if provided) or the columns in
                the table itself.  The method returns the number of rows inserted (0 or 1).
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub single_insert {
    my ($dest_dbc, $table_name, $data, $col_names, $insertion_mode) = @_;

    my $n_values = scalar(@$data);
    my $insert_sql = ($insertion_mode || 'INSERT') . ' INTO ' . $table_name;
    $insert_sql .= ' (' . join(',', @$col_names) . ')' if $col_names;
    $insert_sql .= ' VALUES (' . ('?,'x($n_values-1)) . '?)';
    my $nrows = $dest_dbc->do($insert_sql, undef, @$data) or die "Could not execute the insert because of ".$dest_dbc->db_handle->errstr;
    return $nrows;
}


=head2 bulk_insert

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $dest_dbc
  Arg[2]      : string $table_name
  Arg[3]      : arrayref of arrayrefs $data
  Arg[4]      : (opt) arrayref of strings $col_names (defaults to the column-order at the database level)
  Arg[5]      : (opt) string $insertion_mode (default: 'INSERT')

  Description : Execute extended INSERT statements (or whatever flavour selected in $insertion_mode)
                on $dest_dbc to push the data kept in the arrayref $data.  Each arrayref in $data
                corresponds to a row, in the same order as in $col_names (if provided) or the columns
                in the table itself.  The method returns the total number of rows inserted
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub bulk_insert {
    my ($dest_dbc, $table_name, $data, @args) = @_;

    return bulk_insert_iterator($dest_dbc, $table_name, Bio::EnsEMBL::Utils::Iterator->new($data), @args);
}


=head2 bulk_insert_iterator

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $dest_dbc
  Arg[2]      : string $table_name
  Arg[3]      : Bio::EnsEMBL::Utils::Iterator over the data to insert
  Arg[4]      : (opt) arrayref of strings $col_names (defaults to the column-order at the database level)
  Arg[5]      : (opt) string $insertion_mode (default: 'INSERT')

  Description : Execute extended INSERT statements (or whatever flavour selected in $insertion_mode)
                on $dest_dbc to push the data returned by the iterator $data_iterator.  Each element
                in the iterator corresponds to a row, in the same order as in $col_names (if provided)
                or the columns in the table itself.  The method returns the total number of rows inserted
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub bulk_insert_iterator {
    my ($dest_dbc, $table_name, $data_iterator, $col_names, $insertion_mode, $ignore_fks, $debug) = @_;

    printf("bulk insert %s foreign keys into %s\n", ($ignore_fks ? 'without': 'with', $table_name)) if $debug;
    my $insert_n   = 0;
    my $to_dbh = $dest_dbc->db_handle;
    $dest_dbc->do("SET FOREIGN_KEY_CHECKS = 0") if $ignore_fks;
    while ($data_iterator->has_next) {
        my $insert_sql = ($insertion_mode || 'INSERT') . ' INTO ' . $table_name;
        $insert_sql .= ' (' . join(',', @$col_names) . ')' if $col_names;
        $insert_sql .= ' VALUES ';
        my $first = 1;
        while ($data_iterator->has_next and (length($insert_sql) < MAX_STATEMENT_LENGTH)) {
            my $row = $data_iterator->next;
            $insert_sql .= ($first ? '' : ', ') . '(' . join(',', map {$to_dbh->quote($_)} @$row) . ')';
            $first = 0;
        }
        my $this_time = $dest_dbc->do($insert_sql) or die "Could not execute the insert because of ".$dest_dbc->db_handle->errstr;
        $insert_n += $this_time;
    }
    $dest_dbc->do("SET FOREIGN_KEY_CHECKS = 1") if $ignore_fks;
    print "inserted $insert_n rows\n" if $debug;
    return $insert_n;
}


1;
