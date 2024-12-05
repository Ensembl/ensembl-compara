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


sub fetch_input {
    my ($self) = @_;

    my $clusterset_id = $self->param_required('clusterset_id');
    my $member_type = $self->param_required('member_type');
    my $member_type_map = $self->param_required('member_type_map');

    my $mlss_dba = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $method_dba = $self->compara_dba->get_MethodAdaptor();

    my $method_type;
    if ($member_type eq 'protein') {
        $method_type = 'PROTEIN_TREES';
    } elsif ($member_type eq 'ncrna') {
        $method_type = 'NCRNA_TREES';
    } else {
        $self->die_no_retry("unknown member_type: $member_type");
    }

    my $mlss = $mlss_dba->fetch_by_method_link_type_species_set_name($method_type, $clusterset_id);
    my $collection = $mlss->species_set;

    my @collection_gdbs = grep { !$_->genome_component } @{$collection->genome_dbs};
    my %gdb_id_to_name = map { $_->dbID => $_->name } @collection_gdbs;
    my @collection_gdb_ids = sort { $a <=> $b } keys %gdb_id_to_name;

    my $homology_methods = $method_dba->fetch_all_by_class_pattern('^Homology\.homology$');
    my @homology_method_types = map { $_->type } @{$homology_methods};

    my %gdb_to_hom_mlss_ids;
    foreach my $method_type (@homology_method_types) {
        foreach my $i ( 0 .. $#collection_gdb_ids ) {
            my $gdb1_id = $collection_gdb_ids[$i];
            foreach my $j ( $i .. $#collection_gdb_ids ) {
                my $gdb2_id = $collection_gdb_ids[$j];

                my @homology_mlss_gdb_ids;
                if ($gdb2_id == $gdb1_id) {  # e.g. homoeology MLSS
                    @homology_mlss_gdb_ids = ($gdb1_id);
                } else {  # e.g. orthology MLSS
                    @homology_mlss_gdb_ids = ($gdb1_id, $gdb2_id);
                }

                my $mlss = $mlss_dba->fetch_by_method_link_type_GenomeDBs($method_type, \@homology_mlss_gdb_ids);
                next unless defined $mlss and $mlss->is_current;
                foreach my $gdb_id (@homology_mlss_gdb_ids) {
                    push(@{$gdb_to_hom_mlss_ids{$gdb_id}}, $mlss->dbID);
                }
            }
        }
    }

    my @biotype_groups = @{$member_type_map->{$member_type}};
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
                JOIN genome_db gdb1 USING (genome_db_id)
                JOIN seq_member sm1 USING (seq_member_id)
            ) USING (homology_id)
            JOIN (
                homology_member hm2
                JOIN gene_member gm2 USING (gene_member_id)
                JOIN genome_db gdb2 USING (genome_db_id)
                JOIN seq_member sm2 USING (seq_member_id)
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

            if (defined $is_high_confidence) {
                $cset_hom_counts{'expected_strict_orthology_count'} += $hom_count * $is_high_confidence;
                $cset_hom_counts{'expected_orthology_count'} += $hom_count;
            }
        }
    }

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
            'species_name' => $gdb_id_to_name{$gdb_id},
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
