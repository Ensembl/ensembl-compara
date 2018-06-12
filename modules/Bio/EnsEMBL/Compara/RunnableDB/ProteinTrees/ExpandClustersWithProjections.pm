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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExpandClustersWithProjections

=head1 DESCRIPTION

This is the RunnableDB that parses the output of Hcluster, stores the
clusters as trees without internal structure (each tree will have one
root and several leaves) and dataflows the cluster_ids down branch #2.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExpandClustersWithProjections;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub param_defaults {
    return {
            'sort_clusters'         => 1,
            'immediate_dataflow'    => 0,
    };
}


my $sql_expand_clusters = 'INSERT INTO gene_tree_node (parent_id, root_id, seq_member_id)
SELECT gtn.parent_id, gtn.root_id, smp.target_seq_member_id
FROM gene_tree_node gtn JOIN seq_member_projection smp ON gtn.seq_member_id = smp.source_seq_member_id
LEFT JOIN gene_tree_node gtn2 ON gtn2.seq_member_id = smp.target_seq_member_id WHERE gtn2.seq_member_id IS NULL
';

my $sql_update_gene_count = 'UPDATE gene_tree_root_attr
  JOIN (SELECT root_id, COUNT(seq_member_id) AS real_size FROM gene_tree_node GROUP BY root_id) _t USING (root_id)
  JOIN gene_tree_root USING (root_id)
SET gene_count = real_size
WHERE tree_type = "tree"
';

my $sql_unexpandable_members = 'SELECT source_seq_member_id, target_seq_member_id
FROM seq_member_projection smp JOIN seq_member ON source_seq_member_id = seq_member_id LEFT JOIN gene_tree_node gtn1 USING (seq_member_id) LEFT JOIN gene_tree_node gtn2 ON gtn2.seq_member_id = smp.target_seq_member_id
WHERE gtn1.node_id IS NULL
AND gtn2.seq_member_id IS NULL
';

sub fetch_input {
    my $self = shift;
    my $this_mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param_required('mlss_id'));
    $self->param('member_type', $this_mlss->method->type eq 'PROTEIN_TREES' ? 'protein' : 'ncrna');
}

sub run {
    my $self = shift @_;

    # Add genes to the clusters
    $self->compara_dba->dbc->do($sql_expand_clusters);
    $self->compara_dba->dbc->do($sql_update_gene_count);

    # Find the source genes that are not in clusters
    my %allclusters = ();
    $self->param('allclusters', \%allclusters);

    my $division      = $self->param('division'),
    my $sth = $self->compara_dba->dbc->prepare($sql_unexpandable_members);
    $sth->execute();
    while (my $row = $sth->fetchrow_arrayref()) {
        if (exists $allclusters{$row->[0]}) {
            push @{ $allclusters{$row->[0]}->{'members'} }, $row->[1];
        } else {
            $allclusters{$row->[0]} = { 'members' => [@$row] };
            $allclusters{$row->[0]}->{'division'} = $division if $division;
        }
    }
    $sth->finish();
    warn scalar(keys %allclusters), " clusters added\n";
}


sub write_output {
    my $self = shift @_;

    #die;
    $self->store_clusterset('default', $self->param('allclusters')) if scalar(keys %{$self->param('allclusters')});
}

1;
