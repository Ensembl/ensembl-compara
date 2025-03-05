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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::HomologyGenomeMLSSFactory

=head1 DESCRIPTION

This runnable generates dataflows for dumping homologies per genome and MLSS.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::HomologyGenomeMLSSFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'fan_branch_code'    => 3,
        'funnel_branch_code' => 2,
    }
}


sub run {
    my ($self) = @_;

    my $clusterset_id = $self->param_required('clusterset_id');
    my $member_type = $self->param_required('member_type');

    my $mlss_dba = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $method_dba = $self->compara_dba->get_MethodAdaptor();

    my $method_type;
    if ($member_type eq 'protein') {
        $method_type = 'PROTEIN_TREES';
    } elsif ($member_type eq 'ncrna') {
        $method_type = 'NC_TREES';
    } else {
        $self->die_no_retry("unknown member_type: $member_type");
    }

    my $mlss = $mlss_dba->fetch_by_method_link_type_species_set_name($method_type, $clusterset_id);
    my $collection = $mlss->species_set;

    my @collection_gdbs = grep { !$_->genome_component } @{$collection->genome_dbs};

    my %gdb_info;
    foreach my $gdb (@collection_gdbs) {
        $gdb_info{$gdb->dbID} = {
            'species_name' => $gdb->name,
            'species_path' => $gdb->_get_ftp_dump_relative_path(),
        };
    }

    my $homology_mlsses = $mlss_dba->_fetch_gene_tree_homology_mlsses($mlss);

    my %gdb_id_to_name;
    my %is_ortholog_mlss;
    my %gdb_to_hom_mlss_ids;
    foreach my $homology_mlss (@{$homology_mlsses}) {
        $is_ortholog_mlss{$homology_mlss->dbID} = $homology_mlss->method->type eq 'ENSEMBL_ORTHOLOGUES';
        foreach my $gdb (@{$homology_mlss->species_set->genome_dbs}) {
            push(@{$gdb_to_hom_mlss_ids{$gdb->dbID}}, $homology_mlss->dbID);
            $gdb_id_to_name{$gdb->dbID} = $gdb->name;
        }
    }

    my @biotype_groups = @{$mlss->get_gene_tree_member_biotype_groups()};
    my $biotype_group_placeholders = '(' . join(',', ('?') x @biotype_groups) . ')';
    my $biotype_group_sql_list = "('" . join("','", @biotype_groups) . "')";

    my $helper = $self->compara_dba->dbc->sql_helper;

    my %gdb_mlss_hom_counts;
    my %gdb_hom_counts;
    my %cset_hom_counts;
    foreach my $gdb_id (sort keys %gdb_to_hom_mlss_ids) {
        my @hom_mlss_ids = @{$gdb_to_hom_mlss_ids{$gdb_id}};

        print STDERR "Querying homologies of genome with dbID $gdb_id ...\n" if $self->debug;

        my $hom_mlss_id_placeholders = '(' . join(',', ('?') x @hom_mlss_ids) . ')';

        my $sql = qq/
            SELECT
                method_link_species_set_id,
                is_high_confidence,
                COUNT(*)
            FROM
                homology h
            JOIN (
                homology_member hm1
                JOIN gene_member gm1 USING (gene_member_id)
            ) USING (homology_id)
            JOIN (
                homology_member hm2
            ) USING (homology_id)
            WHERE
                method_link_species_set_id IN $hom_mlss_id_placeholders
                AND hm1.gene_member_id > hm2.gene_member_id
                AND gm1.biotype_group IN $biotype_group_placeholders
                AND gm1.genome_db_id = ?
            GROUP BY
                method_link_species_set_id,
                is_high_confidence;
        /;

        my $params = [@hom_mlss_ids, @biotype_groups, $gdb_id];
        my $results = $helper->execute( -SQL => $sql, -PARAMS => $params );

        foreach my $result (@{$results}) {
            my ($hom_mlss_id, $is_high_confidence, $hom_count) = @{$result};

            $gdb_mlss_hom_counts{$gdb_id}{$hom_mlss_id}{'expected_homology_count'} += $hom_count;
            $gdb_hom_counts{$gdb_id}{'expected_homology_count'} += $hom_count;
            $cset_hom_counts{'expected_homology_count'} += $hom_count;

            if ($is_ortholog_mlss{$hom_mlss_id}) {
                $cset_hom_counts{'expected_strict_orthology_count'} += $hom_count * $is_high_confidence;
                $cset_hom_counts{'expected_orthology_count'} += $hom_count;
            }
        }
    }

    $self->compara_dba->dbc->disconnect_if_idle;

    foreach my $gdb_id (sort keys %gdb_to_hom_mlss_ids) {
        my @hom_mlss_ids = @{$gdb_to_hom_mlss_ids{$gdb_id}};

        my @input_list;
        foreach my $hom_mlss_id (@hom_mlss_ids) {
            my $mlss_exp_line_count = $gdb_mlss_hom_counts{$gdb_id}{$hom_mlss_id}{'expected_homology_count'} // 0;
            push(@input_list, [$hom_mlss_id, $mlss_exp_line_count]);
        }

        my $gdb_exp_line_count = $gdb_hom_counts{$gdb_id}{'expected_homology_count'} // 0;
        my %fan_output_id = (
            'genome_db_id' => $gdb_id,
            'species_name' => $gdb_info{$gdb_id}{'species_name'},
            'species_path' => $gdb_info{$gdb_id}{'species_path'},
            'biotype_group_list' => $biotype_group_sql_list,
            'genome_exp_line_count' => $gdb_exp_line_count,
            'column_names' => ['hom_mlss_id', 'exp_line_count'],
            'inputlist' => \@input_list,
        );

        $self->dataflow_output_id(\%fan_output_id, $self->param('fan_branch_code'));
    }

    my %funnel_output_id = (
        'exp_ortho_count' => $cset_hom_counts{'expected_orthology_count'},
        'exp_strict_ortho_count' => $cset_hom_counts{'expected_strict_orthology_count'},
        'clusterset_exp_line_count' => $cset_hom_counts{'expected_homology_count'},
    );
    $self->dataflow_output_id(\%funnel_output_id, $self->param('funnel_branch_code'));
}


1;
