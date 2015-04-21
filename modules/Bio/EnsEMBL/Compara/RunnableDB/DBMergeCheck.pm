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

Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 SYNOPSYS

This Runnable needs the following parameters:
 - db_aliases: hash of 'db_alias' -> URL to connect to the database
 - curr_rel_name: alias of the target database
 - master_name: alias of the master database

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
use Bio::EnsEMBL::Hive::Utils ('url2dbconn_hash');

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {

        # Special databases
        'curr_rel_name'     => 'curr_rel_db',   # the target database
        'master_name'       => 'master_db',     # the master database (gives the list of tables that shouldn't be copied)

        # Static list of tables that must be ignored
        'production_tables' => [qw(ktreedist_score recovered_member cmsearch_hit CAFE_data gene_tree_backup split_genes mcl_sparse_matrix statistics constrained_element_production dnafrag_chunk lr_index_offset dnafrag_chunk_set dna_collection)],
        'hive_tables'       => [qw(accu hive_meta analysis_base analysis_data job job_file log_message analysis_stats analysis_stats_monitor analysis_ctrl_rule dataflow_rule worker monitor resource_description resource_class lsf_report analysis job_message pipeline_wide_parameters role worker_resource_usage)],

        # How to compare overlapping data. Primary keys are read from the schema unless overriden here
        'primary_keys'      => {
            'gene_tree_root_tag'    => 'root_id',
            'gene_tree_node_tag'    => 'node_id',
            'species_tree_node_tag' => 'node_id',
            'CAFE_species_gene'     => 'node_id',
            'dnafrag_region'        => 'synteny_region_id',
            'constrained_element'   => 'constrained_element_id',
        },

        # Maximum number of elements that we are allowed to fetch to check for a primary key conflict
        'max_nb_elements_to_fetch'  => 50e6
    };
}

sub fetch_input {
    my $self = shift @_;

    my $db_aliases = $self->param_required('db_aliases');
    my $exclusive_tables = $self->param_required('exclusive_tables');
    my $ignored_tables = $self->param_required('ignored_tables');
    my $curr_rel_name = $self->param('curr_rel_name');

    my $connection_params = {map {$_ => url2dbconn_hash($self->param_required($_))} @$db_aliases};

    my $dbconnections = {map {$_ => Bio::EnsEMBL::DBSQL::DBConnection->new(%{$connection_params->{$_}})} keys %{$connection_params}};
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
    foreach my $db (@$db_aliases) {

        # Production-only tables
        my @bad_tables_list = (@{$self->param('hive_tables')}, @{$self->param('production_tables')});

        # We don't care about tables that are exclusive to another db
        push @bad_tables_list, (grep {$exclusive_tables->{$_} ne $db} (keys %$exclusive_tables));

        # We want all the tables on the release database to detect production tables
        my $extra = $db eq $curr_rel_name ? " IS NOT NULL " : " ";

        # We may want to ignore some more tables
        push @bad_tables_list, @{$ignored_tables->{$db}} if exists $ignored_tables->{$db};
        my @wildcards =  grep {$_ =~ /\%/} @{$ignored_tables->{$db}};
        $extra .= join("", map {" AND table_name NOT LIKE '$_' "} @wildcards);

        my $bad_tables = join(',', map {"'$_'"} @bad_tables_list);
        my $sql = "SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema = ? AND table_type = 'BASE TABLE' AND table_name NOT IN ($bad_tables) AND table_rows $extra";
        my $list = $dbconnections->{$db}->db_handle->selectall_arrayref($sql, undef, $connection_params->{$db}->{-dbname});
        $table_size->{$db} = {map {$_->[0] => $_->[1]} @$list};
    }
    print Dumper($table_size) if $self->debug;
    # WARNING: In InnoDB mode, table_rows is an approximation of the true number of rows
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
        # We only want the first column of the primary key
        while (my $row = $sth->fetch) {
            $key = $row->[3] if $row->[4] == 1;
        }
        die " -ERROR- No primary key for table '$table'" unless defined $key;
        $primary_keys->{$table} = $key;
    }

    # Key type
    my $key_type = $dbconnection->db_handle->column_info(undef, undef, $table, $key)->fetch->[5];
    my $is_string_type = ($key_type =~ /char/i ? 1 : 0);
    # We only accept char and int
    die "'$key_type' type is not handled" unless $is_string_type or $key_type =~ /int/i;

    return ($key, $is_string_type);

}

sub run {
    my $self = shift @_;

    my $curr_rel_name = $self->param('curr_rel_name');
    my $master_name = $self->param('master_name');
    my $table_size = $self->param('table_size');
    my $exclusive_tables = $self->param('exclusive_tables');
    my $only_tables = $self->param_required('only_tables');
    my $dbconnections = $self->param('dbconnections');

    # Structures the information per table
    my $all_tables = {};
    foreach my $db (keys %$dbconnections) {
        next if $db eq $curr_rel_name;

        my @ok_tables;

        if (exists $only_tables->{$db}) {

            # If we want some specific tables, they should be non-empty
            foreach my $table (@{$only_tables->{$db}}) {
                die "'$table' should be non-empty in '$db'" unless exists $table_size->{$db}->{$table};
                push @ok_tables, $table;
            }

        } else {

            # The master database is a reference: most of its tables are discarded
            foreach my $table (keys %{$table_size->{$db}}) {
                next if (exists $table_size->{$master_name}->{$table} and not grep {$_ eq $table} @{$only_tables->{$master_name}});
                push @ok_tables, $table;
            }
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

        unless (exists $table_size->{$curr_rel_name}->{$table} or exists $exclusive_tables->{$table}) {
            die "The table '$table' exists in ".join("/", @{$all_tables->{$table}})." but not in the target database\n";
        }

        if (not $table_size->{$curr_rel_name}->{$table} and scalar(@{$all_tables->{$table}}) == 1) {

            my $db = $all_tables->{$table}->[0];

            # Single source -> copy
            print "$table is copied over from $db\n" if $self->debug;
            $copy{$table} = $db;

        } else {

            my ($key, $is_string_type) = $self->_find_primary_key($dbconnections->{$all_tables->{$table}->[0]}, $table);

            # Multiple source -> merge (possibly with the target db)
            my @dbs = @{$all_tables->{$table}};
            push @dbs, $curr_rel_name if $table_size->{$curr_rel_name}->{$table};
            print "$table is merged from ", join(" and ", @dbs), "\n" if $self->debug;

            my $sql = "SELECT MIN($key), MAX($key), COUNT($key) FROM $table";
            my $min_max = {map {$_ => $dbconnections->{$_}->db_handle->selectall_arrayref($sql)->[0] } @dbs};
            my $bad = 0;
            map { $table_size->{$_}->{$table} = $min_max->{$_}->[2] } @dbs;

            # min and max values must not overlap
            foreach my $db1 (@dbs) {
                foreach my $db2 (@dbs) {
                    next if $db2 le $db1;
                    if ($is_string_type) {
                        $bad = 1 if $min_max->{$db1}->[1] ge $min_max->{$db2}->[0] and $min_max->{$db2}->[1] ge $min_max->{$db1}->[0];
                    } else {
                        $bad = 1 if $min_max->{$db1}->[1] >= $min_max->{$db2}->[0] and $min_max->{$db2}->[1] >= $min_max->{$db1}->[0];
                    }
                    last if $bad;
                }
                last if $bad;
            }
            if ($bad) {

                unless (grep { $table_size->{$_}->{$table} > $self->param('max_nb_elements_to_fetch') } @dbs) {

                    print " -INFO- comparing the actual values of the primary key\n" if $self->debug;
                    # We really make sure that no value is shared between the tables
                    $sql = "SELECT DISTINCT $key FROM $table";
                    my %all_values = ();
                    foreach my $db (@dbs) {
                        my $sth = $dbconnections->{$db}->prepare($sql, { 'mysql_use_result' => 1 });
                        $sth->execute;
                        my $value;
                        $sth->bind_columns(\$value);
                        while ($sth->fetch) {
                            die sprintf(" -ERROR- for the key '%s', the value '%s' is present in several copies\n", $key, $value) if exists $all_values{$value};
                            $all_values{$value} = 1
                        }
                    }

                } else {
                    die " -ERROR- ranges of the key '$key' overlap, and there are too many elements to perform an extensive check\n", Dumper($min_max);
                }
            }
            print " -INFO- ranges of the key '$key' are fine\n" if $self->debug;
            $merge{$table} = $all_tables->{$table};

        }
    }
    $self->param('copy', \%copy);
    $self->param('merge', \%merge);
}


sub write_output {
    my $self = shift @_;

    my $table_size = $self->param('table_size');
    my $curr_rel_name = $self->param('curr_rel_name');
    my $primary_keys = $self->param('primary_keys');

    # If in write_output, it means that there are no ID conflict. We can safely dataflow the copy / merge operations.

    while ( my ($table, $db) = each(%{$self->param('copy')}) ) {
        $self->dataflow_output_id( {'src_db_conn' => "#$db#", 'table' => $table}, 2);
    }

    while ( my ($table, $dbs) = each(%{$self->param('merge')}) ) {
        my $n_total_rows = $table_size->{$curr_rel_name}->{$table} || 0;
        my @inputlist = ();
        foreach my $db (@$dbs) {
            push @inputlist, [ "#$db#" ];
            $n_total_rows += $table_size->{$db}->{$table};
        }
        $self->dataflow_output_id( {'table' => $table, 'inputlist' => \@inputlist, 'n_total_rows' => $n_total_rows, 'key' => $primary_keys->{$table}}, 3);
    }

}

1;


 
