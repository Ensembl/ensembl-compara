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

use Bio::EnsEMBL::Compara::Graph::Link;

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
    my @children = @{$ancestor->children};
    while (@children) {
        my $child1 = shift @children;
        foreach my $child2 (@children) {

            # Paralogues
            my $n_para = $self->add_other_paralogs_for_pair($ancestor, $child1, $child2);
            $ngenepairlinks += $n_para;

            # When checking all the genome_db_ids we should find some paralogues
            unless ($n_para or $self->param('genome_db_id')) {
                # If not, the sub-families are across different parts of the taxonomy and we are missing some orthologs. Let's add them !
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


1;
