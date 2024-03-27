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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::DBMerge::CopyHomologiesByMLSS

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DBMerge::CopyHomologiesByMLSS;

use strict;
use warnings;

use File::Spec::Functions;
use JSON qw(decode_json);

use Bio::EnsEMBL::Utils::IO qw(slurp_to_array);
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

        foreach my $mlss_id (@{$mlss_info->{'mlss_id'}}) {
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

    } elsif ($table_name =~ /^(hmm_annot|peptide_align_feature)$/) {

        my $mlss_set_gdb_ids = '(' . join(',', @{$mlss_info->{'genome_db_id'}}) . ')';

        my $query;
        if ($table_name eq 'hmm_annot') {
            $query = qq/
                SELECT
                    hmm_annot.*
                FROM
                    hmm_annot
                JOIN
                    seq_member
                USING
                    (seq_member_id)
                WHERE
                    seq_member.genome_db_id IN $mlss_set_gdb_ids
            /;
        } else {
            $query = qq/
                SELECT
                    peptide_align_feature.*
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
                    qmember.genome_db_id IN $mlss_set_gdb_ids
                AND
                    hmember.genome_db_id IN $mlss_set_gdb_ids
            /;
        }

        copy_data($from_dbc, $to_dbc, $table_name, $query, $replace, $self->param('skip_disable_vars'), $self->debug);

    } else {
        $self->die_no_retry("Per-MLSS merge of $table_name has not been implemented");
    }
}

1;
