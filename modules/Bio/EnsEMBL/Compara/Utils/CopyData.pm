=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

This package exports method to copy_data between databases.
copy_data() is usually used to copy whole tables or large chunks of data,
without paying attention to the foreign-key constraints. It has two
specialized version copy_data_in_binary_mode() and copy_data_in_text_mode()
that are automatically used depending on the data-types in the table.
copy_data_with_foreign_keys_by_constraint() can copy individual rows with
their own depedencies. It will also "expand" the data, for instance by
copying homology_member too when asked to copy homology_member.

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::Utils::CopyData (:row_copy);
  # The ", 1" at the end tells the function to "expand" the data, i.e. copy
  # extra rows to make the objects complete. Without it, it wouldn't copy
  # family_member
  copy_data_with_foreign_keys_by_constraint($source_dbc, $target_dbc, 'family', 'stable_id', 'ENSFM00730001521062', 1);
  copy_data_with_foreign_keys_by_constraint($source_dbc, $target_dbc, 'gene_tree_root', 'stable_id', 'ENSGT00390000003602', 1);

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
    copy_data_in_binary_mode
    copy_data_in_text_mode
);
%EXPORT_TAGS = (
  'row_copy'    => [qw(copy_data_with_foreign_keys_by_constraint clear_copy_data_cache)],
  'table_copy'  => [qw(copy_data copy_data_in_binary_mode copy_data_in_text_mode)],
  'all'         => [@EXPORT_OK]
);


use Data::Dumper;


my %foreign_key_cache = ();

my %data_expansions = (
    'ncbi_taxa_node' => [['taxon_id', 'ncbi_taxa_name', 'taxon_id'], ['parent_id', 'ncbi_taxa_node', 'taxon_id']],
    'gene_tree_root' => [['root_id', 'gene_tree_root_tag', 'root_id'], ['root_id', 'gene_tree_root', 'ref_root_id'], ['root_id', 'gene_tree_node', 'root_id'], ['root_id', 'homology', 'gene_tree_root_id'], ['root_id', 'CAFE_gene_family', 'gene_tree_root_id']],
    'CAFE_gene_family' => [['cafe_gene_family_id', 'CAFE_species_gene', 'cafe_gene_family_id']],
    'gene_tree_node' => [['node_id', 'gene_tree_node_tag', 'node_id'], ['node_id', 'gene_tree_node_attr', 'node_id'], ['root_id', 'gene_tree_root', 'root_id']],
    'species_tree_node' => [['node_id', 'species_tree_node_tag', 'node_id'], ['root_id', 'species_tree_root', 'root_id'], ['parent_id', 'species_tree_node', 'node_id']],
    'method_link_species_set' => [['method_link_species_set_id', 'method_link_species_set_tag', 'method_link_species_set_id'], ['species_set_id', 'species_set', 'species_set_id'], ['species_set_id', 'species_set_tag', 'species_set_id']],
    'family' => [['family_id', 'family_member', 'family_id']],
    'homology' => [['homology_id', 'homology_member', 'homology_id']],
    'gene_align' => [['gene_align_id', 'gene_align_member', 'gene_align_id']],
    'seq_member' => [['seq_member_id', 'other_member_sequence', 'seq_member_id']],
    'gene_member' => [['canonical_member_id', 'seq_member', 'seq_member_id']],
    'synteny_region' => [['synteny_region_id', 'dnafrag_region', 'synteny_region_id']],
    'genomic_align_block' => [['genomic_align_block_id', 'genomic_align', 'genomic_align_block_id'], ['genomic_align_block_id', 'conservation_score', 'genomic_align_block_id']],
    # FIXME: how to expand genomic_align_tree ?

);


=head2 copy_data_with_foreign_keys_by_constraint

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $from_dbc
  Arg[2]      : Bio::EnsEMBL::DBSQL::DBConnection $to_dbc
  Arg[3]      : string $table_name
  Arg[4]      : string $where_field: the name of the column to use for the filtering
  Arg[5]      : string $where_value: the value of the column used for the filtering
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
    load_foreign_keys($_[1]);
    memoized_insert(@_);
}

# Load all the foreign keys and cache the result
sub load_foreign_keys {
    my $dbc = shift;

    return $foreign_key_cache{$dbc->locator} if $foreign_key_cache{$dbc->locator};

    my $sth = $dbc->db_handle->foreign_key_info(undef, $dbc->dbname, undef, undef, undef, undef);
    my %fk = ();
    foreach my $x (@{ $sth->fetchall_arrayref() }) {
        # A.x REFERENCES B.y : push @{$fk{'A'}}, ['x', 'B', 'y'];
        push @{$fk{$x->[6]}}, [$x->[7], $x->[2], $x->[3]];
    }
    $foreign_key_cache{$dbc->locator} = \%fk;
    return \%fk;
}


my %cached_inserts = ();
sub memoized_insert {
    my ($from_dbc, $to_dbc, $table, $where_field, $where_value, $foreign_keys_dbc, $expand_tables) = @_;

    my $key = join("||||", $from_dbc->locator, $to_dbc->locator, $table, $where_field, $where_value);
    return if $cached_inserts{$key};
    $cached_inserts{$key} = 1;

    $foreign_keys_dbc ||= $to_dbc;

    my $sql_select = sprintf('SELECT * FROM %s WHERE %s = ?', $table, $where_field);
    #warn "<< $sql_select  using '$where_value'\n";
    my $sth = $from_dbc->prepare($sql_select);
    $sth->execute($where_value);
    while (my $h = $sth->fetchrow_hashref()) {
        my %this_row = %$h;

        # First insert the requirements (to satisfy the foreign keys)
        insert_related_rows($from_dbc, $to_dbc, \%this_row, load_foreign_keys($foreign_keys_dbc)->{$table}, $table, $where_field, $where_value, $foreign_keys_dbc, $expand_tables);

        # Then the data
        my @cols = keys %this_row;
        my @qms  = map {'?'} @cols;
        my @vals = @this_row{@cols};
        my $insert_sql = sprintf('INSERT IGNORE INTO %s (%s) VALUES (%s)', $table, join(',', @cols), join(',', @qms));
        #warn ">> $insert_sql using '", join("','", @vals), "'\n";
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
        insert_related_rows($from_dbc, $to_dbc, \%this_row, $data_expansions{$table}, $table, $where_field, $where_value, $foreign_keys_dbc, $expand_tables) if $expand_tables;
    }
}

sub insert_related_rows {
    my ($from_dbc, $to_dbc, $this_row, $rules, $table, $where_field, $where_value, $foreign_keys_dbc, $expand_tables) = @_;
    foreach my $x (@$rules) {
        #warn sprintf("%s(%s) needs %s(%s)\n", $table, @$x);
        if (not defined $this_row->{$x->[0]}) {
            next;
        } elsif (($table eq $x->[1]) and ($where_field eq $x->[2]) and ($where_value eq $this_row->{$x->[0]})) {
            # self-loop catcher: the code is about to store the same row again and again
            # we fall here when trying to insert a root gene_tree_node because its root_id links to itself
            next;
        }
        memoized_insert($from_dbc, $to_dbc, $x->[1], $x->[2], $this_row->{$x->[0]}, $foreign_keys_dbc, $expand_tables);
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
  Arg[4]      : (opt) string $index_name
  Arg[5]      : (opt) integer $min_id
  Arg[6]      : (opt) integer $max_id
  Arg[7]      : (opt) string $query
  Arg[8]      : (opt) integer $step
  Arg[9]      : (opt) boolean $disable_keys (default: true)
  Arg[10]     : (opt) boolean $reenable_keys (default: true)
  Arg[11]     : (opt) boolean $holes_possible (default: false)

  Description : Copy data in this table. The main optional arguments are:
                 - ($index_name,$min_id,$max_id) to restrict to a range
                 - $query for a general way of altering the data (e.g. fixing it)

=cut

sub copy_data {
    my ($from_dbc, $to_dbc, $table_name, $index_name, $min_id, $max_id, $query, $step, $disable_keys, $reenable_keys, $holes_possible) = @_;

    print "Copying data in table $table_name\n";

    my $sth = $from_dbc->db_handle->column_info($from_dbc->dbname, undef, $table_name, '%');
    $sth->execute;
    my $all_rows = $sth->fetchall_arrayref;
    my $binary_mode = 0;
    foreach my $this_col (@$all_rows) {
        if (($this_col->[5] eq "BINARY") or ($this_col->[5] eq "VARBINARY") or
            ($this_col->[5] eq "BLOB") or ($this_col->[5] eq "BIT")) {
            $binary_mode = 1;
            last;
        }
    }
    die "Keys must be disabled in order to be reenabled\n" if $reenable_keys and not $disable_keys;

    #When merging the patches, there are so few items to be added, we have no need to disable the keys
    if ($disable_keys // 1) {
        #speed up writing of data by disabling keys, write the data, then enable
        #but takes far too long to ENABLE again
        $to_dbc->do("ALTER TABLE `$table_name` DISABLE KEYS");
    }
    if ($binary_mode) {
        copy_data_in_binary_mode($from_dbc, $to_dbc, $table_name, $index_name, $min_id, $max_id, $query, $step);
    } else {
        copy_data_in_text_mode($from_dbc, $to_dbc, $table_name, $index_name, $min_id, $max_id, $query, $step, $holes_possible);
    }
    if ($reenable_keys // 1) {
        $to_dbc->do("ALTER TABLE `$table_name` ENABLE KEYS");
    }
}


=head2 copy_data_in_text_mode

  Description : A specialized version of copy_data() for tables that don't have
                any binary data and can be loaded with mysqlimport.

=cut

sub copy_data_in_text_mode {
    my ($from_dbc, $to_dbc, $table_name, $index_name, $min_id, $max_id, $query, $step, $holes_possible) = @_;

    my $user = $to_dbc->username;
    my $pass = $to_dbc->password;
    my $host = $to_dbc->host;
    my $port = $to_dbc->port;
    my $dbname = $to_dbc->dbname;

    #Default step size.
    $step ||= 10000;

    my ($use_limit, $start);
    if (defined $index_name && defined $min_id && defined $max_id) {
        # We'll use BETWEEN
        $use_limit = 0;
        $start = $min_id;
    } else {
        # We'll use LIMIT 
        $use_limit = 1;
        $start = 0;
    }
    # $use_limit also tells whether $start and $end are counters or values comparable to $index_name

    while (1) {
        my $end = $start + $step - 1;
        my $sth;
        my $sth_attribs = { 'mysql_use_result' => 1 };

        #print "start $start end $end\n";
        if ($use_limit) {
            $sth = $from_dbc->prepare( $query." LIMIT $start, $step", $sth_attribs );
        } else {
            $sth = $from_dbc->prepare( $query." AND $index_name BETWEEN $start AND $end", $sth_attribs );
        }
        $start += $step;
        $sth->execute();
        my $first_row = $sth->fetchrow_arrayref;

        ## EXIT CONDITION
        if (!$first_row) {
            # We're told there could be holes in the data, and $end hasn't yet reached $max_id
            next if ($holes_possible and !$use_limit and ($end < $max_id));
            # Otherwise it is the end
            return;
        }

        my $time = time(); 
        my $filename = "/tmp/$table_name.copy_data.$$.$time.txt";
        open(my $fh, '>', $filename) or die "could not open the file '$filename' for writing";
        print $fh join("\t", map {defined($_)?$_:'\N'} @$first_row), "\n";
        my $nrows = 1;
        while(my $this_row = $sth->fetchrow_arrayref) {
            print $fh join("\t", map {defined($_)?$_:'\N'} @$this_row), "\n";
            $nrows++;
        }
        close($fh);
        $sth->finish;
        #print "start $start end $end $max_id rows $nrows\n";
        #print "FILE $filename\n";
        #print "time " . ($start-$min_id) . " " . (time - $start_time) . "\n";
        system('mysqlimport', "-h$host", "-P$port", "-u$user", $pass ? ("-p$pass") : (), '--local', '--lock-tables', '--ignore', $dbname, $filename);

        unlink($filename);
    }
}

=head2 copy_data_in_binary_mode

  Description : A specialized version of copy_data() for tables that have binary
                data, using mysqldump.

=cut

sub copy_data_in_binary_mode {
    my ($from_dbc, $to_dbc, $table_name, $index_name, $min_id, $max_id, $query, $step) = @_;

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

    my $use_limit = 0;
    my $start = $min_id;
    my $direct_copy = 0;

    #all the data in the table needs to be copied and does not need fixing
    if (!defined $query) {
        #my $start_time  = time();

        system("mysqldump -h$from_host -P$from_port -u$from_user ".($from_pass ? "-p$from_pass" : '')." --insert-ignore -t $from_dbname $table_name ".
            "| mysql   -h$to_host   -P$to_port   -u$to_user   ".($to_pass ? "-p$to_pass" : '')." $to_dbname");

        #print "time " . ($start-$min_id) . " " . (time - $start_time) . "\n";

        return;
    }

    print " ** WARNING ** Copying table $table_name in binary mode, this requires write access.\n";
    print " ** WARNING ** The original table will be temporarily renamed as original_$table_name.\n";
    print " ** WARNING ** An auxiliary table named temp_$table_name will also be created.\n";
    print " ** WARNING ** You may have to undo this manually if the process crashes.\n\n";

    #If not using BETWEEN, revert back to LIMIT
    if (!defined $index_name && !defined $min_id && !defined $max_id) {
        $use_limit = 1;
        $start = 0;
    }
    #my $start = 0;
    if (!defined $step) {
        $step = 1000000;
    }
    while (1) {
        #my $start_time  = time();
        my $end = $start + $step - 1;
        #print "start $start end $end\n";

        ## Copy data into a aux. table
        my $sth;
        if (!$use_limit) {
            $sth = $from_dbc->prepare("CREATE TABLE temp_$table_name $query AND $index_name BETWEEN $start AND $end");
        } else {
            $sth = $from_dbc->prepare("CREATE TABLE temp_$table_name $query LIMIT $start, $step");
        }
        $sth->execute();

        $start += $step;
        my $count = $from_dbc->db_handle->selectrow_array("SELECT count(*) FROM temp_$table_name");

        ## EXIT CONDITION
        if (!$count) {
            $from_dbc->db_handle->do("DROP TABLE temp_$table_name");
            return;
        }

        ## Change table names (mysqldump will keep the table name, hence we need to do this)
        $from_dbc->db_handle->do("ALTER TABLE $table_name RENAME original_$table_name");
        $from_dbc->db_handle->do("ALTER TABLE temp_$table_name RENAME $table_name");

        ## mysqldump data

        system("mysqldump -h$from_host -P$from_port -u$from_user ".($from_pass ? "-p$from_pass" : '')." --insert-ignore -t $from_dbname $table_name ".
            "| mysql   -h$to_host   -P$to_port   -u$to_user   ".($to_pass ? "-p$to_pass" : '')." $to_dbname");

        #print "time " . ($start-$min_id) . " " . (time - $start_time) . "\n";

        ## Undo table names change
        $from_dbc->db_handle->do("DROP TABLE $table_name");
        $from_dbc->db_handle->do("ALTER TABLE original_$table_name RENAME $table_name");

        #print "total time " . ($start-$min_id) . " " . (time - $start_time) . "\n";
    }
}


1;
 
