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
    - some tables may be merged per MLSS if configured
 3. When merging, the runnable checks that the data does not overlap
    - first by comparing the interval of the primary key
    - then comparing the actual values if needed
    - additionally by comparing method_link_species_set_ids or genome_db_ids, if merging per MLSS
 4. If everything is fine, the jobs are all dataflown

Primary keys can most of the time be guessed from the schema.
However, you can define the hash primary_keys as 'table' => 'column_name'
to override some of the keys / provide them if they are not part of the schema.
They don't have to be the whole primary key on their own, they can simply be a
representative column that can be used to check for overlap between databases.
Currently, only INT anc CHAR columns are allowed.

Some tables can be configured to be merged per MLSS, assuming that certain constraints are satisfied.
The main constraint is that per-MLSS merge is intended for merging homology data from gene-tree pipeline
databases with a defined member type and collection. It cannot be used for merging from a prevous release
database, nor can it be used for incremental merging of homology data into the current release database,
since a release database could have homologies involving genes of various member types and collections,
and the current implementation of per-MLSS merge does not have a mechanism for disentangling them.

The Runnable will complain if:
 - no primary key is defined / can be found for a table that needs to be merged
 - the primary key is not INT or CHAR
 - the tables refered by the "only_tables" parameter should all be non-empty
 - the tables refered by the "exclusive_tables" parameter should all be non-empty
 - all the non-production and non-eHive tables of the source databases should
   exist in the target database
 - some tables that need to be merged share a value of their primary key
 - the constraints of a per-MLSS merge are violated (if using per-MLSS merge)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck;

use strict;
use warnings;
use Data::Dumper;
use File::Spec::Functions;
use JSON ('encode_json');
use List::Util ('sum');

use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::Hive::HivePipeline;
use Bio::EnsEMBL::Hive::Utils ('destringify', 'go_figure_dbc', 'stringify');
use Bio::EnsEMBL::Compara::Utils::Database ('table_exists');

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {

        # Static list of the main tables that must be ignored (their
        # content exclusively comes from the master database)
        'master_tables'     => [qw(meta genome_db species_set species_set_header method_link method_link_species_set ncbi_taxa_node ncbi_taxa_name dnafrag)],
        # Static list of production tables that must be ignored
        'production_tables' => [qw(
            anchor_align
            anchor_sequence
            CAFE_data
            cmsearch_hit
            constrained_element_production
            dnafrag_chunk
            dnafrag_chunk_set
            dna_collection
            gene_tree_backup
            homology_id_mapping
            id_assignments
            id_generator
            ktreedist_score
            lr_index_offset
            mcl_sparse_matrix
            ortholog_goc_metric
            prev_ortholog_goc_metric
            recovered_member
            split_genes
            statistics
        )],

        # Configurable list of tables to merge per MLSS
        'per_mlss_merge_tables' => [],

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
        my $table_list = $this_db_handle->selectall_hashref($sql_table_status, 'Name');
        # print Dumper $table_list;
        $table_size->{$db} = {};
        foreach my $t (keys %$table_list) {
            my ($s) = $this_db_handle->selectrow_array("SELECT 1 FROM $t LIMIT 1");
            $s //= 0;
            # my $s = $table_list->{$t}->{'Rows'};
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
    my $per_mlss_merge_tables = $self->param('per_mlss_merge_tables') // [];

    my $master_dba = $self->get_cached_compara_dba('master_db');

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

    my %src_db_to_mlss_info;
    if (scalar(@{$per_mlss_merge_tables}) > 0) {

        my %src_db_to_table_set;
        while (my ($table, $db_aliases) = each %{$all_tables}) {
            foreach my $db (@{$db_aliases}) {
                $src_db_to_table_set{$db}{$table} = 1;
            }
        }

        my %gdb_id_to_db;
        my %gdb_pair_to_db;
        my %mlss_id_to_dbs;
        my %db_to_nr_mlss_ids;
        my %hom_mlss_key_to_db;
        foreach my $db (@{$src_db_aliases}, 'curr_rel_db') {
            my $src_dbc = $dbconnections->{$db};
            my $src_db_helper = $src_dbc->sql_helper;

            my @relevant_per_mlss_merge_tables;
            if ($db eq 'curr_rel_db') {
                @relevant_per_mlss_merge_tables = grep { exists $table_size->{$db}->{$_} && $table_size->{$db}->{$_} > 0 } @{$per_mlss_merge_tables};
            } else {
                @relevant_per_mlss_merge_tables = grep { exists $src_db_to_table_set{$db}{$_} } @{$per_mlss_merge_tables};
            }

            next unless(@relevant_per_mlss_merge_tables);

            my %rel_per_mlss_merge_table_set = map { $_ => 1 } @relevant_per_mlss_merge_tables;

            my $mlss_info;
            my @supported_per_mlss_merge_tables;
            if (table_exists($src_dbc, 'job')) {  # following example of Bio::EnsEMBL::DataCheck::Utils::is_compara_ehive_db

                my $hive_pipeline = Bio::EnsEMBL::Hive::HivePipeline->new(
                    -no_sql_schema_version_check => 1,
                    -dbconn => $src_dbc,
                );

                my $pipeline_param_dba = $hive_pipeline->hive_dba->get_PipelineWideParametersAdaptor();

                my $mlss_id = destringify(
                    $pipeline_param_dba->fetch_all("param_name = 'mlss_id'", 'one_per_key', undef, 'param_value')
                );

                if (defined $mlss_id) {

                    my $member_type = destringify(
                        $pipeline_param_dba->fetch_all("param_name = 'member_type'", 'one_per_key', undef, 'param_value')
                    );

                    my $mlss = $master_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
                    $mlss_info = $mlss->_find_homology_mlss_sets();

                    # Pipelines with collections can be merged per homology MLSS and member type.
                    # This allows for merging protein and ncRNA homologies in the same MLSS from
                    # a protein-tree and ncRNA-tree pipeline database, respectively.
                    foreach my $hom_mlss_id (@{$mlss_info->{'complementary_mlss_ids'}}) {
                        my $hom_mlss_key = $member_type . ' homology MLSS ' . $hom_mlss_id;
                        if (exists $hom_mlss_key_to_db{$hom_mlss_key}) {
                            $self->die_no_retry(
                                sprintf(
                                    " -ERROR- %s would be merged from both '%s' and '%s', so it cannot be merged per MLSS",
                                    $hom_mlss_key, $db, $hom_mlss_key_to_db{$hom_mlss_key}
                                )
                            );
                        }
                        $hom_mlss_key_to_db{$hom_mlss_key} = $db;
                        push(@{$mlss_id_to_dbs{$hom_mlss_id}}, $db);
                    }

                    $mlss_info->{'gene_tree_mlss_id'} = $mlss_id;

                } else {  # database lacks collection info

                    # MLSS IDs in the homology table are used indirectly for homology_member.
                    @supported_per_mlss_merge_tables = ('homology', 'method_link_species_set_attr', 'method_link_species_set_tag');

                    foreach my $table ('hmm_annot', 'peptide_align_feature') {
                        if (exists $rel_per_mlss_merge_table_set{$table}) {
                            $self->die_no_retry(" -ERROR- Without a collection parameter, cannot merge table '$table' of database '$db' per MLSS");
                        }
                    }
                }

            } else {  # database is not a Hive pipeline

                @supported_per_mlss_merge_tables = ('method_link_species_set_attr', 'method_link_species_set_tag');

                foreach my $table ('hmm_annot', 'homology', 'homology_member', 'peptide_align_feature') {
                    if (exists $rel_per_mlss_merge_table_set{$table}) {
                        $self->die_no_retry(" -ERROR- Cannot merge table '$table' of non-Hive database '$db' per MLSS");
                    }
                }
            }

            if (!defined $mlss_info) {
                my @usable_per_mlss_merge_tables = grep { exists $rel_per_mlss_merge_table_set{$_} } @supported_per_mlss_merge_tables;
                next unless(@usable_per_mlss_merge_tables);

                # Without collection info, all we can do is take all method_link_species_set_ids from
                # usable tables and check later that they do not clash with any other source database.
                my @mlss_id_queries = map { qq/SELECT DISTINCT method_link_species_set_id FROM $_/ } @usable_per_mlss_merge_tables;
                my $mlss_id_union_query = join(' UNION ', @mlss_id_queries);
                my $db_mlss_ids = $src_db_helper->execute_simple( -SQL => $mlss_id_union_query );
                $mlss_info = { 'complementary_mlss_ids' => $db_mlss_ids, 'complementary_gdb_ids' => [], 'overlap_gdb_ids' => [] };

                $db_to_nr_mlss_ids{$db} = $db_mlss_ids;
                foreach my $mlss_id (@{$db_mlss_ids}) {
                    push(@{$mlss_id_to_dbs{$mlss_id}}, $db);
                }
            }

            if (scalar(@{$mlss_info->{'complementary_mlss_ids'}}) > 0) {
                $src_db_to_mlss_info{$db} = $mlss_info;
            }
        }

        # At this point we should have MLSS info for all source databases, so we can
        # check for any MLSS ID clashes involving databases lacking collection info.
        while (my ($db, $nr_mlss_ids) = each %db_to_nr_mlss_ids) {
            foreach my $nr_mlss_id (@{$nr_mlss_ids}) {
                my @other_dbs_with_mlss_id = grep { $_ ne $db } @{$mlss_id_to_dbs{$nr_mlss_id}};
                if (scalar(@other_dbs_with_mlss_id) > 0) {
                    $self->die_no_retry(
                        sprintf(
                            " -ERROR- MLSS %s would be merged from database '%s' and %d other databases (e.g. '%s'), so it cannot be merged per MLSS",
                            $nr_mlss_id, $db, scalar(@other_dbs_with_mlss_id), $other_dbs_with_mlss_id[0]
                        )
                    );
                }
            }
        }
    }

    my %copy = ();
    my %merge = ();
    # We decide whether the table needs to be copied or merged (and if the IDs don't overlap)
    my @table_order = grep { $_ !~ /homology/ } keys %$all_tables;
    push( @table_order, grep { $_ =~ /homology/ } keys %$all_tables ); # do these last, since they take longest
    foreach my $table (@table_order) { # start with smallest tables
        #Record all the errors then die after all the values were checked, reporting the list of errors:
        my %error_list;

        my $merging_table_per_mlss = scalar(grep {$_ eq $table} @{$per_mlss_merge_tables}) ? 1 : 0;

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

            my $sql = "SELECT MIN($key), MAX($key) FROM $table";
            my $min_max = {map {$_ => $dbconnections->{$_}->db_handle->selectrow_arrayref($sql) } @dbs};
            my $bad = 0;

            # Since the counts may not be accurate, we need to update the hash
            foreach my $db (@dbs) {
                my $mlss_info_param = $merging_table_per_mlss ? $src_db_to_mlss_info{$db} : undef;
                $table_size->{$db}->{$table} = $self->_get_effective_table_size($dbconnections->{$db}, $table, $mlss_info_param);

                if ($merging_table_per_mlss && $table_size->{$db}->{$table} > 0 && !exists $src_db_to_mlss_info{$db}) {
                    $self->die_no_retry("Per-MLSS merge info could not be obtained for database '$db', so cannot merge table '$table' per MLSS");
                }
            }
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

                if ($merging_table_per_mlss && $table =~ /^(hmm_annot|method_link_species_set_attr|method_link_species_set_tag|peptide_align_feature)$/) {

                    if ($table eq 'peptide_align_feature') {
                        # Per-MLSS merge of the peptide_align_feature table requires
                        # that there is no overlap between peptide_align_feature_ids.
                        $self->die_no_retry(" -ERROR- ranges of the key '$key' overlap, so cannot merge table 'peptide_align_feature' per MLSS");
                    } elsif ($table eq 'method_link_species_set_tag') {

                        my @gene_tree_mlss_ids;
                        foreach my $db (@dbs) {
                            if (exists $src_db_to_mlss_info{$db} && exists $src_db_to_mlss_info{$db}{'gene_tree_mlss_id'}) {
                                push(@gene_tree_mlss_ids, $src_db_to_mlss_info{$db}{'gene_tree_mlss_id'});
                            }
                        }

                        my $gene_tree_mlss_id_str = '(' . join(',', @gene_tree_mlss_ids) . ')';
                        my $keys = join(",", @$full_key);
                        $sql = qq/SELECT $keys FROM $table WHERE method_link_species_set_id IN $gene_tree_mlss_id_str/;
                        $self->_check_primary_keys(\@dbs, $dbconnections, $table, $keys, $sql);

                    } else {
                        # With the current per-MLSS merge implementation, a key clash is not possible when merging
                        # either of the hmm_annot or method_link_species_set_attr tables.
                        print " -INFO- merging $table by MLSS, skipping range check of key '$key'\n" if $self->debug;
                    }

                } elsif (grep { $table_size->{$_}->{$table} <= $self->param('max_nb_elements_to_fetch') } @dbs) {

                    print " -INFO- comparing the actual values of the primary key\n" if $self->debug;
                    my $keys = join(",", @$full_key);
                    # We really make sure that no value is shared between the tables
                    $sql = "SELECT $keys FROM $table";
                    $self->_check_primary_keys(\@dbs, $dbconnections, $table, $keys, $sql);

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
    $self->param('src_db_to_mlss_info', \%src_db_to_mlss_info);
}


sub write_output {
    my $self = shift @_;

    my $table_size = $self->param('table_size');
    my $primary_keys = $self->param('primary_keys');

    my $per_mlss_merge_tables = $self->param('per_mlss_merge_tables') // [];
    my $src_db_to_mlss_info = $self->param('src_db_to_mlss_info');

    if (scalar(@{$per_mlss_merge_tables}) > 0) {
        my $mlss_info_dir = $self->param_required('mlss_info_dir');

        while (my ($db, $mlss_info) = each %{$src_db_to_mlss_info}) {
            my $registry_name = $self->param_required($db);
            my $mlss_info_file = catfile($mlss_info_dir, "${registry_name}.json");
            $self->_spurt($mlss_info_file, encode_json($mlss_info));
        }
    }

    # If in write_output, it means that there are no ID conflict. We can safely dataflow the copy / merge operations.

    while ( my ($table, $db) = each(%{$self->param('copy')}) ) {
        warn "ACTION: copy '$table' from '$db'\n" if $self->debug;
        $self->dataflow_output_id( {'src_db_conn' => "#$db#", 'table' => $table}, 2);
    }

    while ( my ($table, $dbs) = each(%{$self->param('merge')}) ) {
        my $merging_table_per_mlss = scalar(grep {$_ eq $table} @{$per_mlss_merge_tables}) ? 1 : 0;
        my $n_total_rows = $table_size->{'curr_rel_db'}->{$table} || 0;
        # my @inputlist = ();
        my @input_id_list = ();
        foreach my $db (@$dbs) {
            # push @inputlist, [ "#$db#" ];
            push @input_id_list, { src_db_conn => "#$db#" };
            $n_total_rows += $table_size->{$db}->{$table};
        }
        warn "ACTION: merge '$table' from ".join(", ", map {"'$_'"} @$dbs)."\n" if $self->debug;
        $self->dataflow_output_id( {
            'table'          => $table,
            'input_id_list'  => \@input_id_list,
            'n_total_rows'   => $n_total_rows,
            'key'            => $primary_keys->{$table}->[0],
            'merge_per_mlss' => $merging_table_per_mlss,
        }, 3);
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


sub _check_primary_keys {
    my ($self, $dbnames, $dbconnections, $table, $keys, $sql) = @_;

    my %all_values = ();
    foreach my $dbname (@{$dbnames}) {
        my $sth = $dbconnections->{$dbname}->prepare($sql, { 'mysql_use_result' => 1 });
        $sth->execute;
        while (my $cols = $sth->fetchrow_arrayref()) {
            my $value = join(",", map {$_ // '<NULL>'} @$cols);
            if (exists $all_values{$value}) {
                $self->die_no_retry(
                    sprintf(
                        " -ERROR- for the key %s(%s), the value '%s' is present in '%s' and '%s'\n",
                        $table,
                        $keys,
                        $value,
                        $dbname,
                        $all_values{$value},
                    )
                );
            }
            $all_values{$value} = $dbname;
        }
    }
}

sub _get_effective_table_size {
    my ($self, $src_dbc, $table_name, $mlss_info) = @_;
    my $helper = $src_dbc->sql_helper;

    my $n_rows = 0;
    if (defined $mlss_info) {

        my $sql;
        if ($table_name =~ /^(homology|homology_member|method_link_species_set_attr|method_link_species_set_tag)$/) {

            my $table_queried = $table_name;
            my $multiplier = 1;

            # To save time getting the effective table size of the homology_member table,
            # we query the homology table and multiply the number of homologies by two.
            if ($table_name eq 'homology_member') {
                $table_queried = 'homology';
                $multiplier = 2;
            }

            my $sql = qq/
                SELECT
                    method_link_species_set_id AS mlss_id,
                    COUNT(*) AS n_rows
                FROM
                    $table_queried
                GROUP BY
                    method_link_species_set_id
            /;

            my $mlss_query_results = $helper->execute( -SQL => $sql, -USE_HASHREFS => 1 );
            my %mlss_to_row_count = map { $_->{'mlss_id'} => $_->{'n_rows'} } @$mlss_query_results;

            my @rel_mlss_ids = @{$mlss_info->{'complementary_mlss_ids'}};
            # If a source database has gene-tree MLSS tags, we
            # should count them towards the effective table size.
            if ($table_name eq 'method_link_species_set_tag' && exists $mlss_info->{'gene_tree_mlss_id'}) {
                push(@rel_mlss_ids, $mlss_info->{'gene_tree_mlss_id'});
            }

            $n_rows = sum map { $mlss_to_row_count{$_} // 0 } @rel_mlss_ids;
            $n_rows *= $multiplier;

        } elsif ($table_name eq 'hmm_annot') {

            my @complementary_gdb_ids = @{$mlss_info->{'complementary_gdb_ids'}};

            if (@complementary_gdb_ids) {
                my $compl_gdb_id_placeholders = '(' . join(',', ('?') x @complementary_gdb_ids) . ')';

                my $sql = qq/
                    SELECT
                        COUNT(*)
                    FROM
                        hmm_annot
                    JOIN
                        seq_member
                    USING
                        (seq_member_id)
                    WHERE
                        seq_member.genome_db_id IN $compl_gdb_id_placeholders
                /;

                $n_rows = $helper->execute_single_result( -SQL => $sql, -PARAMS => \@complementary_gdb_ids );
            }

        } elsif ($table_name eq 'peptide_align_feature') {

            my $sql_total = q/SELECT COUNT(*) FROM peptide_align_feature/;
            $n_rows = $helper->execute_single_result( -SQL => $sql_total );

            my @overlap_gdb_ids = @{$mlss_info->{'overlap_gdb_ids'}};
            if (@overlap_gdb_ids) {
                my $overlap_gdb_id_placeholders = '(' . join(',', ('?') x @overlap_gdb_ids) . ')';

                my $sql_overlap = qq/
                    SELECT
                        COUNT(*)
                    FROM
                        peptide_align_feature
                    JOIN
                        seq_member qmember
                    ON
                        qmember_id = qmember.seq_member_id
                    JOIN
                        seq_member hmember
                    ON
                        hmember_id = hmember.seq_member_id
                    WHERE
                        qmember.genome_db_id IN $overlap_gdb_id_placeholders
                    AND
                        hmember.genome_db_id IN $overlap_gdb_id_placeholders
                /;

                $n_rows -= $helper->execute_single_result( -SQL => $sql_overlap, -PARAMS => [@overlap_gdb_ids, @overlap_gdb_ids] );
            }

        } else {
            $self->die_no_retry("Effective table size calculation of $table_name has not been implemented");
        }

    } else {
        my $sql = qq/SELECT COUNT(*) FROM $table_name/;
        $n_rows = $helper->execute_single_result( -SQL => $sql );
    }

    return $n_rows;
}

1;
