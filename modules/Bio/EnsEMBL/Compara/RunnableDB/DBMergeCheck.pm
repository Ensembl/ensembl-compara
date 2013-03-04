=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

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
        'production_tables' => [qw(ktreedist_score recovered_member removed_member cmsearch_hit CAFE_data protein_tree_backup protein_tree_qc split_genes mcl_sparse_matrix statistics constrained_element_production dnafrag_chunk lr_index_offset dnafrag_chunk_set dna_collection)],
        'hive_tables'       => [qw(analysis_base analysis_data job job_file log_message analysis_stats analysis_stats_monitor analysis_ctrl_rule dataflow_rule worker monitor resource_description resource_class lsf_report analysis job_message)],

        # How to compare overlapping data. Primary keys are read from the schema unless overriden here
        'primary_keys'      => {
            'gene_tree_root_tag'    => 'root_id',
            'gene_tree_node_tag'    => 'node_id',
            'species_tree_node_tag' => 'node_id',
            'CAFE_species_gene'     => 'node_id',
            'dnafrag_region'        => 'synteny_region_id',
            'constrained_element'   => 'constrained_element_id',
        },
        # To use string comparison operators instead of < and >
        'string_primary_keys'       => [qw(hmm_profile)],

        # List of tables that are very likely to have overlapping ranges, and small enough so that we can compare the actual values
        'extensive_check_allowed'   => [qw(method_link_species_set_tag sequence member)],
    };
}

sub fetch_input {
    my $self = shift @_;

    my $db_aliases = $self->param_required('db_aliases');
    my $exclusive_tables = $self->param_required('exclusive_tables');
    my $ignored_tables = $self->param_required('ignored_tables');

    my $connection_params = {map {$_ => url2dbconn_hash($self->param_required($_))} @$db_aliases};

    my $dbconnections = {map {$_ => Bio::EnsEMBL::DBSQL::DBConnection->new(%{$connection_params->{$_}})} keys %{$connection_params}};
    $self->param('dbconnections', $dbconnections);

    # Gets the list of non-empty tables for each db
    my $nonempty_tables = {};
    foreach my $db (@$db_aliases) {

        # Production-only tables
        my @bad_tables_list = (@{$self->param('hive_tables')}, @{$self->param('production_tables')});

        # We don't care about tables that are exclusive to another db
        push @bad_tables_list, (grep {$exclusive_tables->{$_} ne $db} (keys %$exclusive_tables));

        # We may want to ignore some more tables
        push @bad_tables_list, @{$ignored_tables->{$db}} if exists $ignored_tables->{$db};
        my @wildcards =  grep {$_ =~ /\%/} @{$ignored_tables->{$db}};
        my $extra = join("", map {" AND table_name NOT LIKE '$_' "} @wildcards);

        my $bad_tables = join(',', map {"'$_'"} @bad_tables_list);
        my $sql = "SELECT table_name FROM information_schema.tables WHERE table_schema = ? AND table_type = 'BASE TABLE' AND table_name NOT IN ($bad_tables) AND table_rows $extra";
        my $list = $dbconnections->{$db}->db_handle->selectall_arrayref($sql, undef, $connection_params->{$db}->{-dbname});
        $nonempty_tables->{$db} = {map {$_->[0] => 1} @$list};
    }
    print Dumper($nonempty_tables) if $self->debug;
    $self->param('nonempty_tables', $nonempty_tables);
}

sub run {
    my $self = shift @_;

    my $curr_rel_name = $self->param('curr_rel_name');
    my $master_name = $self->param('master_name');
    my $nonempty_tables = $self->param('nonempty_tables');
    my $exclusive_tables = $self->param('exclusive_tables');
    my $only_tables = $self->param_required('only_tables');
    my $primary_keys = $self->param('primary_keys');
    my $dbconnections = $self->param('dbconnections');

    # Structures the information per table
    my $all_tables = {};
    foreach my $db (keys %$dbconnections) {
        next if $db eq $curr_rel_name;

        my @ok_tables;

        if (exists $only_tables->{$db}) {

            # If we want some specific tables, they should be non-empty
            foreach my $table (@{$only_tables->{$db}}) {
                die "'$table' should be non-empty in '$db'" unless exists $nonempty_tables->{$db}->{$table};
                push @ok_tables, $table;
            }

        } else {

            # The master database is a reference: most of its tables are discarded
            foreach my $table (keys %{$nonempty_tables->{$db}}) {
                next if (exists $nonempty_tables->{$master_name}->{$table} and not grep {$_ eq $table} @{$only_tables->{$master_name}});
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

        if (not exists $nonempty_tables->{$curr_rel_name}->{$table} and scalar(@{$all_tables->{$table}}) == 1) {

            # Single source -> copy
            print "$table is copied over from ", $all_tables->{$table}->[0], "\n" if $self->debug;
            $copy{$table} = $all_tables->{$table}->[0];

        } else {

            # Multiple source -> merge (possibly with the target db)
            my @dbs = @{$all_tables->{$table}};
            push @dbs, $curr_rel_name if exists $nonempty_tables->{$curr_rel_name}->{$table};
            print "$table is merged from ", join(" and ", @dbs), "\n" if $self->debug;

            # Check on primary key
            my $key = $primary_keys->{$table};
            unless (defined $key) {
                my $sth = $dbconnections->{$curr_rel_name}->db_handle->primary_key_info(undef, undef, $table);
                # We only want the first column of the primary key
                while (my $row = $sth->fetch) {
                    $key = $row->[3] if $row->[4] == 1;
                }
                die " -ERROR- No primary key for table '$table'" unless defined $key;
            }
            my $sql = "SELECT MIN($key), MAX($key) FROM $table";
            my $min_max = {map {$_ => $dbconnections->{$_}->db_handle->selectall_arrayref($sql)->[0] } @dbs};
            my $bad = 0;

            # min and max values must not overlap
            foreach my $db1 (@dbs) {
                foreach my $db2 (@dbs) {
                    next if $db2 le $db1;
                    if (grep {$_ eq $table} @{$self->param('string_primary_keys')})  {
                        $bad = 1 if $min_max->{$db1}->[1] ge $min_max->{$db2}->[0] and $min_max->{$db2}->[1] ge $min_max->{$db1}->[0];
                    } else {
                        $bad = 1 if $min_max->{$db1}->[1] >= $min_max->{$db2}->[0] and $min_max->{$db2}->[1] >= $min_max->{$db1}->[0];
                    }
                    last if $bad;
                }
                last if $bad;
            }
            if ($bad) {

                if (grep {$_ eq $table} @{$self->param('extensive_check_allowed')}) {

                    # We really make sure that no value is shared between the tables
                    $sql = "SELECT DISTINCT $key FROM $table";
                    my $all_values = {map {$_ => $dbconnections->{$_}->db_handle->selectall_arrayref($sql)} @dbs};
                    foreach my $db (@dbs) {
                        $all_values = {map {$_->[0] => 1} @{$all_values->{$db}}};
                    }
                    $bad = undef;
                    foreach my $db1 (@dbs) {
                        foreach my $db2 (@dbs) {
                            next if $db2 le $db1;
                            my @overlap = grep {exists $all_values->{$db2}->{$_}} (keys %{$all_values->{$db1}});
                            $bad = [$overlap[0], $db1, $db2] if scalar(@overlap);
                            last if $bad;
                        }
                        last if $bad;
                    }
                    die sprintf(" -ERROR- for the key '%s', the value '%s' is present in %s and %s\n", $key, @$bad) if $bad;
                } else {
                    die " -ERROR- ranges of the key '$key' overlap\n", Dumper($min_max);
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

    # If in write_output, it means that there are no ID conflict. We can safely dataflow the copy / merge operations.

    while ( my ($table, $db) = each(%{$self->param('copy')}) ) {
        $self->dataflow_output_id( {'src_db_conn' => "#$db#", 'table' => $table}, 2);
    }

    while ( my ($table, $dbs) = each(%{$self->param('merge')}) ) {
        foreach my $db (@$dbs) {
            $self->dataflow_output_id( {'src_db_conn' => "#$db#", 'table' => $table}, 3);
        }
    }

}

1;


 
