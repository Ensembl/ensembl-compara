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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 SYNOPSIS

This Runnable needs the following parameters:
 - src_db_aliases: list of database aliases (the databases to merge)
 - curr_rel_db: alias of the target database
All the above aliases must be resolvable via $self->param(...)

 - master_tables: list of Compara tables that are populated by populate_new_database
 - production_tables: list of Compara production tables (should map ensembl-compara/sql/pipeline-tables.sql)
 - hive_tables: list of eHive tables (should map ensembl-hive/sql/tables.sql)

It works by:
 1. Listing all the tables that are non-empty
 2. Deciding for each table whether they have to be copied over or merged
    - a table is copied (replaced) if there is a single source
    - a table is merged if there are multiple sources (perhaps the target as well)
 3. When merging, the runnable checks that the data does not overlap
    - first by comparing the interval of the primary key
    - then comparing the actual values if needed
 4. If everything is fine, the jobs are all dataflown

Primary keys can most of the time be guessed from the schema.
However, you can define the hash primary_keys as 'table' => 'column_name'
to override some of the keys / provide them if they are not part of the schema.
They don't have to be the whole primary key on their own, they can simply be a
representative column that can be used to check for overlap between databases.
Currently, only INT anc CHAR columns are allowed.

The Runnable will complain if:
 - no primary key is defined / can be found for a table that needs to be merged
 - the primary key is not INT or CHAR
 - the tables refered by the "only_tables" parameter should all be non-empty
 - the tables refered by the "exclusive_tables" parameter should all be non-empty
 - all the non-production and non-eHive tables of the source databases should
   exist in the target database
 - some tables that need to be merged share a value of their primary key

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck;

use strict;
use warnings;
use Data::Dumper;

use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::Hive::Utils ('go_figure_dbc', 'stringify');

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {

        # Static list of the main tables that must be ignored (their
        # content exclusively comes from the master database)
        'master_tables'     => [qw(meta genome_db species_set species_set_header method_link method_link_species_set ncbi_taxa_node ncbi_taxa_name dnafrag)],
        # Static list of production tables that must be ignored
        'production_tables' => [qw(ktreedist_score recovered_member cmsearch_hit CAFE_data gene_tree_backup split_genes mcl_sparse_matrix statistics constrained_element_production dnafrag_chunk lr_index_offset dnafrag_chunk_set dna_collection anchor_sequence anchor_align homology_id_mapping prev_ortholog_goc_metric ortholog_goc_metric)],

        # Do we want to be very picky and die if a table hasn't been listed
        # above / isn't in the target database ?
        'die_if_unknown_table'      => 1,

        # How to compare overlapping data. Primary keys are read from the schema unless overriden here
        'primary_keys'      => {
            'gene_tree_root_tag'    => [ 'root_id', 'tag' ],
            'gene_tree_node_tag'    => [ 'node_id', 'tag' ],
            'species_tree_node_tag' => [ 'node_id', 'tag' ],
            'dnafrag_region'        => [ 'synteny_region_id', ],
            'constrained_element'   => [ 'constrained_element_id', ],
        },

        # Maximum number of elements that we are allowed to fetch to check for a primary key conflict
        'max_nb_elements_to_fetch'  => 50e6
    };
}

sub fetch_input {
    my $self = shift @_;

    $self->dbc->disconnect_if_idle();

    my $src_db_aliases = $self->param_required('src_db_aliases');
    my $exclusive_tables = $self->param_required('exclusive_tables');
    my $ignored_tables = $self->param_required('ignored_tables');

    my $dbconnections = { map {$_ => go_figure_dbc( $self->param_required($_) ) } (@$src_db_aliases, 'curr_rel_db') };

    $self->param('dbconnections', $dbconnections);

    # Expand the exclusive tables that have a "%" in their name
    foreach my $table ( keys %$exclusive_tables ) {
        if ($table =~ /%/) {
            my $sql = "SHOW TABLES LIKE '$table'";
            my $db = delete $exclusive_tables->{$table};
            my $list = $dbconnections->{$db}->db_handle->selectall_arrayref($sql);
            foreach my $expanded_arrayref (@$list) {
                $exclusive_tables->{$expanded_arrayref->[0]} = $db;
            }
        }
    }

    # Gets the list of non-empty tables for each db
    my $table_size = {};
    foreach my $db (keys %$dbconnections) {

        # Production-only tables
        my @bad_tables_list = (@{$self->db->hive_pipeline->list_all_hive_tables}, @{$self->db->hive_pipeline->list_all_hive_views}, @{$self->param('production_tables')}, @{$self->param('master_tables')});

        # We don't care about tables that are exclusive to another db
        push @bad_tables_list, (grep {$exclusive_tables->{$_} ne $db} (keys %$exclusive_tables));

        # We may want to ignore some more tables
        push @bad_tables_list, @{$ignored_tables->{$db}} if exists $ignored_tables->{$db};
        my @wildcards =  grep {$_ =~ /\%/} @{$ignored_tables->{$db}};
        my $extra = join("", map {" AND Name NOT LIKE '$_' "} @wildcards);

        my $this_db_handle = $dbconnections->{$db}->db_handle;
        my $bad_tables = join(',', map {"'$_'"} @bad_tables_list);
        my $sql_table_status = "SHOW TABLE STATUS WHERE Engine IS NOT NULL AND Name NOT IN ($bad_tables) $extra";
        my $table_list = $this_db_handle->selectcol_arrayref($sql_table_status, { Columns => [1] });
        my $sql_size_table = 'SELECT COUNT(*) FROM ';
        $table_size->{$db} = {};
        foreach my $t (@$table_list) {
            my ($s) = $this_db_handle->selectrow_array($sql_size_table.$t);
            # We want all the tables on the release database in order to detect production tables
            # but we only need the non-empty tables of the other databases
            $table_size->{$db}->{$t} = $s if ($db eq 'curr_rel_db') or $s;
        }
    }
    print Dumper($table_size) if $self->debug;
    $self->param('table_size', $table_size);
}

sub _find_primary_key {
    my $self = shift @_;
    my $dbconnection = shift @_;
    my $table = shift @_;

    my $primary_keys = $self->param('primary_keys');

    # Check on primary key
    my $key = $primary_keys->{$table};
    unless (defined $key) {
        my $sth = $dbconnection->db_handle->primary_key_info(undef, undef, $table);
        my @pk = map {$_->[3]} sort {$a->[4] <=> $b->[4]} @{ $sth->fetchall_arrayref() };
        die " -ERROR- No primary key for table '$table'" unless @pk;
        $primary_keys->{$table} = $key = \@pk;
    }

    # Key type
    my $key_type = $dbconnection->db_handle->column_info(undef, undef, $table, $key->[0])->fetch->[5];
    my $is_string_type = ($key_type =~ /char/i ? 1 : 0);
    # We only accept char and int
    die "'$key_type' type is not handled" unless $is_string_type or $key_type =~ /int/i;

    return ($key, $is_string_type);

}

sub run {
    my $self = shift @_;

    $self->dbc->disconnect_if_idle();

    my $table_size = $self->param('table_size');
    my $exclusive_tables = $self->param('exclusive_tables');
    my $only_tables = $self->param_required('only_tables');
    my $src_db_aliases = $self->param_required('src_db_aliases');
    my $dbconnections = $self->param('dbconnections');

    # Structures the information per table
    my $all_tables = {};
    foreach my $db (@{$src_db_aliases}) {

        my @ok_tables;

        if (exists $only_tables->{$db}) {

            # If we want some specific tables, they should be non-empty
            foreach my $table (@{$only_tables->{$db}}) {
                die "'$table' should be non-empty in '$db'" unless exists $table_size->{$db}->{$table};
                push @ok_tables, $table;
            }

        } else {

            # All the non-empty tables
            push @ok_tables, keys %{$table_size->{$db}};
        }
        
        foreach my $table (@ok_tables) {
            $all_tables->{$table} = [] unless exists $all_tables->{$table};
            push @{$all_tables->{$table}}, $db;
        }
    }

    print Dumper($all_tables) if $self->debug;

    # The exclusive tables should all be non-empty
    foreach my $table (keys %$exclusive_tables) {
        die "'$table' should be non-empty in '", $exclusive_tables->{$table}, "'" unless exists $all_tables->{$table};
    }

    my %copy = ();
    my %merge = ();
    # We decide whether the table needs to be copied or merged (and if the IDs don't overlap)
    foreach my $table (keys %$all_tables) {

        #Record all the errors then die after all the values were checked, reporting the list of errors:
        my %error_list;

        unless (exists $table_size->{'curr_rel_db'}->{$table} or exists $exclusive_tables->{$table}) {
            if ($self->param('die_if_unknown_table')) {
                die "The table '$table' exists in ".join("/", @{$all_tables->{$table}})." but not in the target database\n";
            } else {
                $self->warning("The table '$table' exists in ".join("/", @{$all_tables->{$table}})." but not in the target database\n");
                next;
            }
        }

        if (not $table_size->{'curr_rel_db'}->{$table} and scalar(@{$all_tables->{$table}}) == 1) {

            my $db = $all_tables->{$table}->[0];
            $self->_assert_same_table_schema($dbconnections->{$db}, $dbconnections->{'curr_rel_db'}, $table);

            # Single source -> copy
            print "$table is copied over from $db\n" if $self->debug;
            $copy{$table} = $db;

        } else {

            my ($full_key, $is_string_type) = $self->_find_primary_key($dbconnections->{$all_tables->{$table}->[0]}, $table);
            my $key = $full_key->[0];

            # Multiple source -> merge (possibly with the target db)
            my @dbs = @{$all_tables->{$table}};
            push @dbs, 'curr_rel_db' if $table_size->{'curr_rel_db'}->{$table};
            print "$table is merged from ", join(" and ", @dbs), "\n" if $self->debug;

            my $sql = "SELECT MIN($key), MAX($key), COUNT($key) FROM $table";
            my $min_max = {map {$_ => $dbconnections->{$_}->db_handle->selectrow_arrayref($sql) } @dbs};
            my $bad = 0;
            # Since the counts may not be accurate, we need to update the hash
            map { $table_size->{$_}->{$table} = $min_max->{$_}->[2] } @dbs;
            # and re-filter the list of databases
            @dbs = grep {$table_size->{$_}->{$table}} @dbs;

            foreach my $db (@dbs) {
                $self->_assert_same_table_schema($dbconnections->{$db}, $dbconnections->{'curr_rel_db'}, $table);
            }

            my $sql_overlap = "SELECT COUNT(*) FROM $table WHERE $key BETWEEN ? AND ?";

            # min and max values must not overlap
            foreach my $db1 (@dbs) {
                foreach my $db2 (@dbs) {
                    next if $db2 le $db1;
                    # Do the intervals overlap ?
                    if ($is_string_type) {
                        $bad = [$db1,$db2] if ($min_max->{$db1}->[1] ge $min_max->{$db2}->[0]) and ($min_max->{$db2}->[1] ge $min_max->{$db1}->[0]);
                    } else {
                        $bad = [$db1,$db2] if ($min_max->{$db1}->[1] >= $min_max->{$db2}->[0]) and ($min_max->{$db2}->[1] >= $min_max->{$db1}->[0]);
                    }
                    # Is one interval in a "hole" ?
                    if ($bad) {
                        my ($c2_in_1) = $dbconnections->{$db1}->db_handle->selectrow_array($sql_overlap, undef, $min_max->{$db2}->[0], $min_max->{$db2}->[1]);
                        my ($c1_in_2) = $dbconnections->{$db2}->db_handle->selectrow_array($sql_overlap, undef, $min_max->{$db1}->[0], $min_max->{$db1}->[1]);
                        $bad = 0 if !$c2_in_1 or !$c1_in_2;
                    }
                    last if $bad;
                }
                last if $bad;
            }
            if ($bad) {

                unless (grep { $table_size->{$_}->{$table} > $self->param('max_nb_elements_to_fetch') } @dbs) {

                    print " -INFO- comparing the actual values of the primary key\n" if $self->debug;
                    my $keys = join(",", @$full_key);
                    # We really make sure that no value is shared between the tables
                    $sql = "SELECT $keys FROM $table";
                    my %all_values = ();
                    foreach my $db (@dbs) {
                        my $sth = $dbconnections->{$db}->prepare($sql, { 'mysql_use_result' => 1 });
                        $sth->execute;
                        while (my $cols = $sth->fetchrow_arrayref()) {
                            my $value = join(",", map {$_ // '<NULL>'} @$cols);
                            die sprintf(" -ERROR- for the key %s(%s), the value '%s' is present in '%s' and '%s'\n", $table, $keys, $value, $db, $all_values{$value}) if exists $all_values{$value};
                            #push(@error_list, sprintf(" -ERROR- for the key %s(%s), the value '%s' is present in '%s' and '%s'\n", $table, $keys, $value, $db, $all_values{$value})) if exists $all_values{$value};
                            #my @tok = split(/\,/,$value);
                            #$error_list{$tok[0]} = 1 if exists $all_values{$value};
                            $all_values{$value} = $db;
                        }
                    }

                } else {
                    die " -ERROR- ranges of the key '$key' overlap, and there are too many elements to perform an extensive check\n", Dumper($min_max);
                }
            }
            print " -INFO- ranges of the key '$key' are fine\n" if $self->debug;
            $merge{$table} = [grep {$table_size->{$_}->{$table}} @{ $all_tables->{$table} }];

        }
        if (%error_list){
            die "Errors: \n" . join("\n", keys(%error_list)) . "\n";
        }
    }
    $self->param('copy', \%copy);
    $self->param('merge', \%merge);
}


sub write_output {
    my $self = shift @_;

    my $table_size = $self->param('table_size');
    my $primary_keys = $self->param('primary_keys');

    # If in write_output, it means that there are no ID conflict. We can safely dataflow the copy / merge operations.

    while ( my ($table, $db) = each(%{$self->param('copy')}) ) {
        warn "ACTION: copy '$table' from '$db'\n" if $self->debug;
        $self->dataflow_output_id( {'src_db_conn' => "#$db#", 'table' => $table}, 2);
    }

    while ( my ($table, $dbs) = each(%{$self->param('merge')}) ) {
        my $n_total_rows = $table_size->{'curr_rel_db'}->{$table} || 0;
        my @inputlist = ();
        foreach my $db (@$dbs) {
            push @inputlist, [ "#$db#" ];
            $n_total_rows += $table_size->{$db}->{$table};
        }
        warn "ACTION: merge '$table' from ".join(", ", map {"'$_'"} @$dbs)."\n" if $self->debug;
        $self->dataflow_output_id( {'table' => $table, 'inputlist' => \@inputlist, 'n_total_rows' => $n_total_rows, 'key' => $primary_keys->{$table}->[0]}, 3);
    }

}

sub _assert_same_table_schema {
    my ($self, $src_dbc, $dest_dbc, $table) = @_;

    my $src_sth = $src_dbc->db_handle->column_info(undef, undef, $table, '%');
    my $src_schema = $src_sth->fetchall_arrayref;
    $src_sth->finish();

    my $dest_sth = $dest_dbc->db_handle->column_info(undef, undef, $table, '%');
    my $dest_schema = $dest_sth->fetchall_arrayref;
    $dest_sth->finish();

    if (! @$dest_schema){
        return;
    }
    die sprintf("'%s' has a different schema in '%s' and '%s'\n", $table, $src_dbc->dbname, $dest_dbc->dbname) if stringify($src_schema) ne stringify($dest_schema);
}


1;


 
