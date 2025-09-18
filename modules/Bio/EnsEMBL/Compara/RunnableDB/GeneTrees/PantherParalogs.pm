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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PantherParalogs

=head1 DESCRIPTION

Like OtherParalogs, this analysis will load a super gene tree and insert
the extra paralogs into the homology tables. The difference is that it does
not care about node-types, duplication confidence scores, etc and does not
require the super-tree to be binary.


=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PantherParalogs;

use strict;
use warnings;

use List::Util qw(sum);

use Bio::EnsEMBL::Compara::Graph::Link;
use Bio::EnsEMBL::Compara::Graph::Node;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs');


# Just override rec_add_paralogs to allow multifurcations and not bother
# about the node annotation. OtherParalogs does the rest.
sub rec_add_paralogs {
    my $self = shift;
    my $ancestor = shift;

    # Skip the terminal nodes
    return 0 unless $ancestor->get_child_count;

    my $ngenepairlinks = 0;

    # Iterate over all pairs of children
    # while identifying orthologous subclades.
    my @children = @{$ancestor->children};
    my @subclade_graph_links;
    my %subclade_graph_nodes;
    my %subtree_nodes_by_id;
    while (@children) {
        my $child1 = shift @children;
        foreach my $child2 (@children) {

            # Paralogues
            my $n_para = $self->add_other_paralogs_for_pair($ancestor, $child1, $child2);
            $ngenepairlinks += $n_para;

            # When checking all the genome_db_ids we should find some paralogues
            unless ($n_para or $self->param('genome_db_id')) {
                # If not, the sub-families are across different parts of the taxonomy and we are missing some orthologs.
                # Let's add these orthologous subtrees to the subclade graph !

                foreach my $child ($child1, $child2) {
                    my $child_node_id = $child->node_id;
                    if (!exists $subclade_graph_nodes{$child_node_id}) {
                        my $subclade_node = Bio::EnsEMBL::Compara::Graph::Node->new();
                        $subclade_node->node_id($child_node_id);
                        $subclade_graph_nodes{$child_node_id} = $subclade_node;
                        $subtree_nodes_by_id{$child_node_id} = $child;
                    }
                }

                my $subclade1_node = $subclade_graph_nodes{$child1->node_id};
                my $subclade2_node = $subclade_graph_nodes{$child2->node_id};
                my $subclade_link = $subclade1_node->create_link_to_node($subclade2_node);
                push(@subclade_graph_links, $subclade_link);
            }
        }
    }

    {  # <-- These braces were placed here only to minimise the diff between versions; please feel free to remove them.
        if (@subclade_graph_links) {
            foreach my $subclade_link (@subclade_graph_links) {
                my ($subclade1, $subclade2) = $subclade_link->get_nodes();
                my $child1 = $subtree_nodes_by_id{$subclade1->node_id};
                my $child2 = $subtree_nodes_by_id{$subclade2->node_id};
                # The sub-families are across different parts of the taxonomy and we are missing some orthologs. Let's add them !
                my $gene_hash1 = $child1->get_value_for_tag('gene_hash');
                my $gene_hash2 = $child2->get_value_for_tag('gene_hash');
                my $n_ortho = 0;
                foreach my $gdb_id1 (keys %$gene_hash1) {
                    foreach my $gdb_id2 (keys %$gene_hash2) {
                        # NOTE I feel like there is a risk of annotating 1-to-1 from the same gene to
                        # the same species several times, but it doesn't seem to happen in practice ...
                        next if $gdb_id1 == $gdb_id2;   # Orthologues are between different species
                        foreach my $gene1 (@{$gene_hash1->{$gdb_id1}}) {
                            foreach my $gene2 (@{$gene_hash2->{$gdb_id2}}) {
                                my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link($gene1, $gene2);
                                $genepairlink->add_tag("ancestor", $ancestor);
                                $genepairlink->add_tag("subclade_link", $subclade_link);
                                $genepairlink->add_tag("subtrees", \%subtree_nodes_by_id);
                                $genepairlink->add_tag("subtree1", $child1);
                                $genepairlink->add_tag("subtree2", $child2);
                                $self->tag_genepairlink($genepairlink, $self->tag_orthologues($genepairlink), 0);
                            }
                        }
                        $n_ortho += scalar(@{$gene_hash1->{$gdb_id1}}) * scalar(@{$gene_hash2->{$gdb_id2}});
                    }
                }
                $self->warning("Added $n_ortho orthologues between node_id=" . $child1->node_id . " and node_id=". $child2->node_id);
                $ngenepairlinks += $n_ortho;
            }
        }
    }
    foreach my $child (@{$ancestor->children}) {
        $ngenepairlinks += $self->rec_add_paralogs($child);
    }
    return $ngenepairlinks;
}


sub tag_orthologues
{
    my ($self, $genepairlink) = @_;

    my ($pep1, $pep2) = $genepairlink->get_nodes;
    my $gdb_id1 = $pep1->genome_db_id;
    my $gdb_id2 = $pep2->genome_db_id;

    my $subclade_link = $genepairlink->get_value_for_tag('subclade_link');
    my $subtree_nodes_by_id = $genepairlink->get_value_for_tag('subtrees');

    # We take the first linked subclade node as our entry point
    # to the subclade graph, though either one would be OK.
    my ($subclade_node) = $subclade_link->get_nodes();

    # We need orthologue counts by subclade and genome for
    # each of the genomes linked by this orthology relationship.
    my %subclade_counts;
    foreach my $subclade (@{$subclade_node->all_nodes_in_graph()}) {
        my $subtree = $subtree_nodes_by_id->{$subclade->node_id};
        my $species_hash = $self->get_ancestor_species_hash($subtree);
        $subclade_counts{$subclade->node_id}{$gdb_id1} = $species_hash->{$gdb_id1} // 0;
        $subclade_counts{$subclade->node_id}{$gdb_id2} = $species_hash->{$gdb_id2} // 0;
    }

    # From the current subclade graph node representing a set of orthologues, we identify
    # the local subgraph within which every node has genes in one of the two genomes
    # involved in this orthology. All the genes in this subgraph are linked, directly
    # or indirectly, by orthology relationships with the current orthologue pair.
    my @nodes_to_check = ($subclade_node);
    my @connected_subclades;
    my %node_visited;
    while (@nodes_to_check) {
        my $node = pop @nodes_to_check;
        $node_visited{$node->node_id} = 1;
        if ($subclade_counts{$node->node_id}{$gdb_id1} > 0
                || $subclade_counts{$node->node_id}{$gdb_id2} > 0) {
            push(@connected_subclades, $node);
            foreach my $neighbor (@{$node->neighbors}) {
                if (!$node_visited{$neighbor->node_id}) {
                    push(@nodes_to_check, $neighbor);
                }
            }
        }
    }

    # We sum up counts of homologues from each genome from across the local subgraph.
    my $count1 = sum map { $subclade_counts{$_->node_id}{$gdb_id1} } @connected_subclades;
    my $count2 = sum map { $subclade_counts{$_->node_id}{$gdb_id2} } @connected_subclades;

    return $self->_classify_orthologues($count1, $count2);
}


1;
