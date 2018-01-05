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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyClusters

=head1 DESCRIPTION

This RunnableDB reads the protein clusters (Gene-trees) from one
database and copies them over to the current one.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyClusters;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub param_defaults {
    return {
            'sort_clusters'         => 1,
            'member_type'           => 'protein',
            'source_clusterset_id'  => 'default',
            'target_clusterset_id'  => 'default',
            'rejoin_supertrees'     => 1,
            'tags_to_copy'          => [],
            'immediate_dataflow'    => 0,
    };
}


sub run {
    my $self = shift @_;

    $self->read_clusters_from_previous_db;
}


sub write_output {
    my $self = shift @_;

    $self->store_clusterset($self->param('target_clusterset_id'), $self->param('allclusters'));
}


##########################################
#
# internal methods
#
##########################################

sub read_clusters_from_previous_db {
    my $self = shift;

    my $reuse_compara_dba       = $self->get_cached_compara_dba('reuse_db');     # may die if bad parameters
    my $sql_trees      = q{SELECT root_id, seq_member_id FROM gene_tree_node JOIN gene_tree_root USING (root_id) WHERE clusterset_id = ? AND member_type = ? AND tree_type = "tree" AND seq_member_id IS NOT NULL};
    my $sql_supertrees = q{SELECT gtn1.root_id, gtn2.root_id FROM gene_tree_root gtr1 JOIN gene_tree_node gtn1 USING (root_id) JOIN gene_tree_node gtn2 ON gtn2.parent_id = gtn1.node_id AND gtn2.root_id != gtn1.root_id WHERE gtr1.tree_type = "supertree" AND gtr1.clusterset_id = ?};

    my $sth = $reuse_compara_dba->dbc->prepare($sql_trees);
    $sth->execute($self->param('source_clusterset_id'), $self->param('member_type'));
    my $all_trees = $sth->fetchall_arrayref();
    $sth->finish;

    my %supertree_mapping = ();
    if ($self->param('rejoin_supertrees')) {
        $sth = $reuse_compara_dba->dbc->prepare($sql_supertrees);
        $sth->execute($self->param('source_clusterset_id'));
        my $all_supertrees = $sth->fetchall_arrayref();
        foreach my $super_row (@$all_supertrees) {
            my ($supertree_id, $tree_id) = @$super_row;
            $supertree_mapping{$tree_id} = $supertree_id;
        }
        $sth->finish;
    }

    my %allclusters = ();
    $self->param('allclusters', \%allclusters);

    foreach my $cluster_row (@$all_trees) {
        my ($cluster_id, $seq_member_id) = @$cluster_row;
        $cluster_id = $supertree_mapping{$cluster_id} || $cluster_id;
        push @{$allclusters{$cluster_id}{members}}, $seq_member_id;
    }

    if (defined $self->param('tags_to_copy')) {
        my $sql_tags = q{SELECT root_id, value FROM gene_tree_root JOIN gene_tree_root_tag USING (root_id) WHERE clusterset_id = ? AND tag = ?};
        $sth = $reuse_compara_dba->dbc->prepare($sql_tags);
        foreach my $tag (@{$self->param('tags_to_copy')}) {
            $sth->execute($self->param('source_clusterset_id'), $tag);
            my $tag_values = $sth->fetchall_arrayref();
            my %tag_hash = map {$_->[0] => $_->[1]} @$tag_values;
            map {$allclusters{$_}->{$tag} = $tag_hash{$_}} (grep {exists $tag_hash{$_}} (keys %allclusters));
            $sth->finish;
        }
    }

}


1;
