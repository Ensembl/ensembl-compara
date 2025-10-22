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

Bio::EnsEMBL::Compara::RunnableDB::Alignment::FlagOutdatedAlignStats

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Alignment::FlagOutdatedAlignStats;

use strict;
use warnings;

use List::Util qw(sum);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'methods'   => {
        #    'CACTUS_DB' => 2,
        #    'CACTUS_HAL' => 2,
        #    'EPO' => 2,
        #    'EPO_EXTENDED' => 2,
        #    'LASTZ_NET' => 2,
        #    'PECAN' => 2,
        },
    }
}


sub run {
    my $self = shift @_;

    my $mlss_id = $self->param_required('mlss_id');

    my $mlss_dba = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $mlss = $mlss_dba->fetch_by_dbID($mlss_id);
    my $mlss_name = $mlss->name;

    my %outdated_stats;

    my $num_blocks_tag = $mlss->get_tagvalue('num_blocks');
    if (defined $num_blocks_tag) {

        my $stored_num_blocks = $mlss->method->type eq 'EPO'
                              ? 2 * $num_blocks_tag
                              : $num_blocks_tag
                              ;

        my $num_blocks_sql = q/
            SELECT
                COUNT(*)
            FROM
                genomic_align_block
            WHERE
                method_link_species_set_id = ?
        /;

        my $actual_num_blocks = $self->compara_dba->dbc->sql_helper->execute_single_result(
            -SQL => $num_blocks_sql,
            -PARAMS => [$mlss_id],
        );

        if ($stored_num_blocks != $actual_num_blocks) {
            $outdated_stats{'num_blocks'} += 1;
            $self->warning(
                sprintf(
                    "Mismatch between stored num_blocks (%d) and "
                    . "actual value (%d) for MLSS '%s' (mlss_id:%d)",
                    $stored_num_blocks,
                    $actual_num_blocks,
                    $mlss_name,
                    $mlss_id,
                )
            );
        }
    }

    my %stored_genome_lengths;
    my %stored_coding_exon_lengths;
    if ($mlss->species_set->size > 2) {

        my $gdb_id_2_node_hash = $mlss->species_tree && $mlss->species_tree->get_genome_db_id_2_node_hash;
        foreach my $gdb (@{$mlss->species_set->genome_dbs}) {
            my $gdb_id = $gdb->dbID;

            my %gdb_stats;
            foreach my $tag ('coding_exon_length', 'genome_length') {
                if ($gdb_id_2_node_hash
                        && exists $gdb_id_2_node_hash->{$gdb_id}
                        && $gdb_id_2_node_hash->{$gdb_id}->has_tag($tag)) {
                    $gdb_stats{$tag} = $gdb_id_2_node_hash->{$gdb_id}->get_value_for_tag($tag);
                } elsif (defined $mlss->has_tag("${tag}_${gdb_id}")) {
                    $gdb_stats{$tag} = $mlss->get_value_for_tag("${tag}_${gdb_id}");
                }
            }

            if (exists $gdb_stats{'coding_exon_length'}) {
                $stored_coding_exon_lengths{$gdb_id} = $gdb_stats{'coding_exon_length'};
            }

            if (exists $gdb_stats{'genome_length'}) {
                $stored_genome_lengths{$gdb_id} = $gdb_stats{'genome_length'};
            }
        }

    } else {
        my ($ref_gdb, $non_ref_gdb) = $mlss->find_pairwise_reference();

        if (!defined $non_ref_gdb) {
            $non_ref_gdb = $ref_gdb;
        }

        my @non_ref_tags = grep { $mlss->has_tag($_) } ('non_ref_coding_exon_length', 'non_ref_genome_length');
        my %non_ref_stats = map { $_ => $mlss->get_value_for_tag($_) } @non_ref_tags;

        if (exists $non_ref_stats{'non_ref_coding_exon_length'}) {
            $stored_coding_exon_lengths{$non_ref_gdb->dbID} = $non_ref_stats{'non_ref_coding_exon_length'};
        }

        if (exists $non_ref_stats{'non_ref_genome_length'}) {
            $stored_genome_lengths{$non_ref_gdb->dbID} = $non_ref_stats{'non_ref_genome_length'};
        }

        my @ref_tags = grep { $mlss->has_tag($_) } ('ref_coding_exon_length', 'ref_genome_length');
        my %ref_stats = map { $_ => $mlss->get_value_for_tag($_) } @ref_tags;

        if (exists $ref_stats{'ref_coding_exon_length'}) {
            $stored_coding_exon_lengths{$ref_gdb->dbID} = $ref_stats{'ref_coding_exon_length'};
        }

        if (exists $ref_stats{'ref_genome_length'}) {
            $stored_genome_lengths{$ref_gdb->dbID} = $ref_stats{'ref_genome_length'};
        }
    }

    my %id_to_gdb = map { $_->dbID => $_ } @{$mlss->species_set->genome_dbs};
    my %gdb_id_to_name = map { $_ => $id_to_gdb{$_}->name } keys %id_to_gdb;

    if (%stored_genome_lengths) {
        my $dnafrag_dba = $self->compara_dba->get_DnaFragAdaptor();

        my %actual_genome_lengths;
        foreach my $gdb (values %id_to_gdb) {
            my $dnafrags = $dnafrag_dba->fetch_all_by_GenomeDB($gdb, -IS_REFERENCE => 1);
            $actual_genome_lengths{$gdb->dbID} = sum map { $_->length } @{$dnafrags};
        }

        while (my ($gdb_id, $stored_genome_length) = each %stored_genome_lengths) {
            my $actual_genome_length = $actual_genome_lengths{$gdb_id};
            if ($stored_genome_length != $actual_genome_length) {
                $outdated_stats{'genome_length'} += 1;
                $self->warning(
                    sprintf(
                        "Mismatch between stored genome_length (%d) and "
                        . "actual value (%d) for %s in MLSS '%s' (mlss_id:%d)",
                        $stored_genome_length,
                        $actual_genome_length,
                        $gdb_id_to_name{$gdb_id},
                        $mlss_name,
                        $mlss_id,
                    )
                );
            }
        }
    }

    if (%stored_coding_exon_lengths) {
        my $coding_exon_length_sql = q/
            SELECT
                genome_db_id,
                SUM(coding_exon_length)
            FROM
                statistics
            WHERE
                method_link_species_set_id = ?
            GROUP BY
                genome_db_id
        /;

        my $result = $self->dbc->db_handle->selectall_arrayref($coding_exon_length_sql, undef, $mlss_id);

        my %actual_coding_exon_lengths;
        foreach my $row (@{$result}) {
            my ($gdb_id, $coding_exon_length) = @{$row};
            $actual_coding_exon_lengths{$gdb_id} = $coding_exon_length;
        }

        while (my ($gdb_id, $stored_coding_exon_length) = each %stored_coding_exon_lengths) {
            my $actual_coding_exon_length = $actual_coding_exon_lengths{$gdb_id};
            if ($stored_coding_exon_length != $actual_coding_exon_length) {
                $outdated_stats{'coding_exon_length'} += 1;
                $self->warning(
                    sprintf(
                        "Mismatch between stored coding_exon_length (%d) and"
                        . " actual value (%d) for %s in MLSS '%s' (mlss_id:%d)",
                        $stored_coding_exon_length,
                        $actual_coding_exon_length,
                        $gdb_id_to_name{$gdb_id},
                        $mlss_name,
                        $mlss_id,
                    )
                );
            }
        }
    }

    $self->param('outdated_stats', \%outdated_stats);
    $self->param('mlss', $mlss);
}


sub write_output {
    my $self = shift;

    my $outdated_stats = $self->param_required('outdated_stats') // {};
    my $methods = $self->param_required('methods');
    my $mlss = $self->param_required('mlss');

    my $branch_number = $methods->{$mlss->method->type};

    if (%{$outdated_stats}) {
        my $output_id = {'mlss_id' => $mlss->dbID, 'outdated_stats' => $outdated_stats};
        $self->dataflow_output_id($output_id, $branch_number);
    }
}


1;
