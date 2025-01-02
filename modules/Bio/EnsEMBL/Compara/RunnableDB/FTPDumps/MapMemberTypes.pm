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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::MapMemberTypes

=head1 DESCRIPTION

This runnable generates mapping of gene-tree member type to gene member biotype
groups, checking that there is no overlap between the sets of biotype groups.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::MapMemberTypes;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $helper = $self->compara_dba->dbc->sql_helper;

    my $sql = q/
        SELECT DISTINCT
            member_type,
            biotype_group
        FROM
            gene_member gm
        JOIN
            seq_member sm ON sm.seq_member_id = gm.canonical_member_id
        JOIN
            gene_tree_node gtn ON gtn.seq_member_id = sm.seq_member_id
        JOIN
            gene_tree_root gtr ON gtn.root_id = gtr.root_id
        WHERE
            gtr.ref_root_id IS NULL
    /;

    my $results = $helper->execute( -SQL => $sql, -USE_HASHREFS => 1 );

    my %member_type_map;
    my %biotype_group_counts;
    foreach my $result (@{$results}) {
        my $member_type = $result->{'member_type'};
        my $biotype_group = $result->{'biotype_group'};
        push(@{$member_type_map{$member_type}}, $biotype_group);
        $biotype_group_counts{$biotype_group} += 1;
    }

    my @overlapping_biotype_groups = grep { $biotype_group_counts{$_} > 1 } keys %biotype_group_counts;

    if (@overlapping_biotype_groups) {
        $self->die_no_retry(
            sprintf(
                "gene trees of different member types have overlapping biotype groups: %s",
                join(',', @overlapping_biotype_groups),
            )
        );
    }

    $self->param('member_type_map', \%member_type_map);
}


sub write_output {
    my $self = shift;

    $self->dataflow_output_id({'member_type_map' => $self->param('member_type_map')}, 2);
}


1;
