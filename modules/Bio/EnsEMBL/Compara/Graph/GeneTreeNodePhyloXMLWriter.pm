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

package Bio::EnsEMBL::Compara::Graph::GeneTreeNodePhyloXMLWriter;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Graph::GeneTreeNodePhyloXMLWriter

=head1 SYNOPSIS

Variant of GeneTreePhyloXMLWriter that accepts Bio::EnsEMBL::Compara::GeneTreeNode
in write_trees()

=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use base qw/Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter/;


sub _write_tree {
  my ($self, $tree) = @_;

  assert_ref($tree, 'Bio::EnsEMBL::Compara::GeneTreeNode', 'tree');
  my $w = $self->_writer();

  my %attr = (rooted => 'true');
  $attr{type} = $self->tree_type();

  # When the tree is not the entire tree, some columns of the alignment may
  # be full of gaps. Need to remove them
  $self->_prune_alignment($tree) if ($tree->{_root_id} != $tree->{_node_id});

  $self->_load_all($tree->adaptor->db, $tree->get_all_nodes, $tree->get_all_leaves);

  $w->startTag('phylogeny', %attr);
  $self->_process($tree);
  $w->endTag('phylogeny');

  delete $self->{_cached_seq_aligns};

  return;
}

1;

