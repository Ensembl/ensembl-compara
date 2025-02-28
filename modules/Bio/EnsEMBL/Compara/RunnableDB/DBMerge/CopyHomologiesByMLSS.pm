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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::DBMerge::CopyHomologiesByMLSS

=head1 DESCRIPTION

Given MLSS info for a particular source database, this runnable facilitates copying of data
per MLSS from that source database (src_db_conn) to the target database (dest_db_conn).

Most tables are merged by method_link_species_set_id. Some are merged by genome_db_id,
where the set of genome_db_ids corresponds in some way to the species set associated
with the relevant MLSS (or MLSSes).

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DBMerge::CopyHomologiesByMLSS;

use strict;
use warnings;

use File::Spec::Functions;
use JSON qw(decode_json);

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },

        'mode'              => 'ignore',
        'skip_disable_vars' => 0,
    };
}

sub run {
    my $self = shift;

    my $mlss_info_dir = $self->param_required('mlss_info_dir');
    my $src_db_name = $self->param_required('src_db_conn');
    my $mlss_info_file = catfile($mlss_info_dir, "${src_db_name}.json");
    my $mlss_info = decode_json($self->_slurp($mlss_info_file));

    my $from_dbc   = $self->get_cached_compara_dba('src_db_conn')->dbc;
    my $to_dbc     = $self->get_cached_compara_dba('dest_db_conn')->dbc;
    my $table_name = $self->param_required('table');
    my $replace    = $self->param('mode') eq 'ignore' ? 0 : 1;

    my $from_str = $from_dbc->host . '/' . $from_dbc->dbname;
    my $to_str   = $to_dbc->host . '/' . $to_dbc->dbname;
    $self->warning("Copying $table_name per MLSS from $from_str to $to_str");

    if ($table_name =~ /^(homology|homology_member|method_link_species_set_attr|method_link_species_set_tag)$/) {

        foreach my $mlss_id (@{$mlss_info->{'complementary_mlss_ids'}}) {
            $self->warning("Copying data for MLSS $mlss_id") if $self->debug;

            my $query;
            if ($table_name eq 'homology_member') {
                $query = qq/
                    SELECT
                        homology_member.*
                    FROM
                        homology
                    JOIN
                        homology_member
                    USING
                        (homology_id)
                    WHERE
                        method_link_species_set_id = $mlss_id
                /;
            } else {
                $query = qq/
                    SELECT
                        *
                    FROM
                        $table_name
                    WHERE
                        method_link_species_set_id = $mlss_id
                /;
            }

            copy_data($from_dbc, $to_dbc, $table_name, $query, $replace, $self->param('skip_disable_vars'), $self->debug);
        }

    } elsif ($table_name eq 'hmm_annot') {

        my @complementary_gdb_ids = @{$mlss_info->{'complementary_gdb_ids'}};
        if (@complementary_gdb_ids) {
            my $complementary_gdb_id_str = '(' . join(',', @complementary_gdb_ids) . ')';

            my $query = qq/
                SELECT
                    hmm_annot.*
                FROM
                    hmm_annot
                JOIN
                    seq_member
                USING
                    (seq_member_id)
                WHERE
                    seq_member.genome_db_id IN $complementary_gdb_id_str
            /;

            copy_data($from_dbc, $to_dbc, $table_name, $query, $replace, $self->param('skip_disable_vars'), $self->debug);
        }

    } elsif ($table_name eq 'peptide_align_feature') {

        # It's simpler (and faster) to copy everything from the
        # source database and then remove any overlapping data.
        copy_table($from_dbc, $to_dbc, $table_name, undef, $replace, $self->param('skip_disable_vars'), $self->debug);

        my @overlap_gdb_ids = @{$mlss_info->{'overlap_gdb_ids'}};
        if (@overlap_gdb_ids) {
            my $overlap_gdb_id_placeholders = '(' . join(',', ('?') x @overlap_gdb_ids) . ')';

            # The peptide_align_feature_id range is used here to ensure that rows representing overlapping data
            # are only deleted from those rows which have been copied from src_db_conn. This assumes that DBMergeCheck
            # has already verified the peptide_align_feature_ids do not overlap between the various source databases.
            my $paf_id_range_sql = q/SELECT MIN(peptide_align_feature_id), MAX(peptide_align_feature_id) FROM peptide_align_feature/;
            my $paf_id_range_results = $from_dbc->sql_helper->execute( -SQL => $paf_id_range_sql );
            my ($min_paf_id, $max_paf_id) = @{$paf_id_range_results->[0]};

            my $delete_statement = qq/
                DELETE
                    peptide_align_feature
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
                AND
                    peptide_align_feature_id BETWEEN ? AND ?
            /;

            my @delete_params = (@overlap_gdb_ids, @overlap_gdb_ids, $min_paf_id, $max_paf_id);
            $to_dbc->sql_helper->execute_update( -SQL => $delete_statement, -PARAMS => \@delete_params );
        }

    } else {
        $self->die_no_retry("Per-MLSS merge of $table_name has not been implemented");
    }
}

1;
