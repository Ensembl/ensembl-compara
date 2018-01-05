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
  <http://www.ensembl.org/Help/Contact>

=head1 NAME

Bio::EnsEMBL::Compara::CAFEGeneFamilyNode

=head1 DESCRIPTION

Specific class to handle CAFE tree nodes

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::CAFEGeneFamilyNode

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with an underscore (_).

=cut

package Bio::EnsEMBL::Compara::CAFEGeneFamilyNode;

use strict;
use warnings;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::SpeciesTreeNode');



sub lambdas {
    my $self = shift;
    $self->{'_lambdas'} = shift if @_;
    return $self->{'_lambdas'};
}


sub cafe_gene_family_id {
    my ($self, $id) = @_;
    if (defined $id) {
        $self->{'_cafe_gene_family_id'} = $id
    }
    return $self->{'_cafe_gene_family_id'};
}

=head2 n_members

    Arg[1]      : (opt.) <int>
    Example     : my $n_members = $tree->n_memberse
    Description : Getter/Setter for the number of members in the node
                  (gene counts for leaves and CAFE-estimated counts for internal nodes)
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub n_members {
    my ($self, $n_members) = @_;
    if (defined $n_members) {
        $self->{'_n_members'} = $n_members;
    }
    return $self->{'_n_members'};
}

=head2 pvalue

    Arg[1]      : (opt.) <double> pvalue
    Example     : my $pvalue = $tree->pvalue
    Description : Getter/Setter for the pvalue of having an expansion or contraction
                  in the node
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub pvalue {
    my ($self, $pvalue) = @_;
    if (defined $pvalue) {
        $self->{'_pvalue'} = $pvalue;
    }
    return $self->{'_pvalue'};
}

sub pvalue_lim {
    my ($self) = @_;
    return 0.01;
}

=head2 is_node_significant

    Arg[1]      : -none-
    Example     : if ($node->is_node_significant) {#do something with the node}
    Description : Returns if the node has a significant expansion or contraction
    ReturnType  : 0/1 (false/true)
    Exceptions  : none
    Caller      : general

=cut

sub is_node_significant {
    my ($self) = @_;
    return (defined $self->pvalue) && ($self->pvalue < $self->pvalue_lim);
}

=head2 is_expansion

    Arg[1]      : -none-
    Example     : if($node->is_expansion) {#do something with node}
    Description : Returns if a given gene family has been expanded in this node
                  of the species tree even if the expansion is not significant
                  (i.e. only compares the number or members of the nodes with its parent)
    ReturnType  : 0/1 (false/true)
    Exceptions  : none
    Caller      : general

=cut

sub is_expansion {
    my ($self) = @_;
    if ($self->has_parent) {
        return $self->parent->is_expansion if ($self->is_node_significant && ($self->n_members == $self->parent->n_members));
        return 1 if ($self->n_members > $self->parent->n_members);
    }
    return 0;
}


=head2 is_contraction

    Arg[1]      : -none-
    Example     : if($node->is_contraction) {#do something with node}
    Description : Returns if a given gene family has been contracted in this node
                  of the species tree even if the contraction is not significant
                  (i.e. only compares the number or members of the nodes with its parent)
    ReturnType  : 0/1 (false/true)
    Exceptions  : none
    Caller      : general

=cut

sub is_contraction {
    my ($self) = @_;
    if ($self->has_parent) {
        return $self->parent->is_contraction if ($self->is_node_significant && ($self->n_members == $self->parent->n_members));
        return 1 if ($self->n_members < $self->parent->n_members);
    }
    return 0;
}

=head2 lca_reroot

  Arg[1]      : -none-
  Example     : my $lca_tree = $tree->lca_reroot
  Description : Returns the lowest common ancestor of the tree
  ReturnType  : Bio::EnsEMBL::Compara::CAFEGeneFamily
  Exceptions  : none
  Caller      : general

=cut

sub lca_reroot {
    my ($self, $lca_id) = @_;
    for my $node (@{$self->get_all_nodes}) {
        if ($node->node_id == $lca_id) {
            return $node;
            # my $lca_tree = $self->adaptor->fetch_lca_tree($node);
            # return $lca_tree;
        }
    }
    $self->throw("LCA node not found in the tree");
}


1;
